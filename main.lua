--[[
#include /script/Automatic.lua
#include /script/registry.lua

]]--

-- Local is faster than global
--local cacheSort = {}
local checkShape = {}
local vertecies = {}
local G_cache = {}
local octtree = {} 
--local spatialSort = {}

function init()
    starRoutine = coroutine.create(aStar)

    Spawn("MOD/boxes.xml",Transform())
    Spawn("MOD/client.xml",Transform())

    list = {}
    list[#list+1] = FindBody("128",true)
    list[#list+1] = FindBody("64",true)
    list[#list+1] = FindBody("32",true)
    list[#list+1] = FindBody("16",true)
    list[#list+1] = FindBody("8",true)

    local num = 128

    for i=1,#list do
        checkShape[i] = {}
        checkShape[i].size = num/i
        checkShape[i].body = list[i]
        checkShape[i].shapes = GetBodyShapes(list[i])
        for j=1, # checkShape[i].shapes do
            SetTag(checkShape[i].shapes[j],"invisible")
            SetTag(checkShape[i].shapes[j],"unbreakable")
            SetTag(checkShape[i].shapes[j],"ground")
        end
    end

    
    mapName = removeForwardSlashes(GetString("game.levelpath"))
    if GetBool("savegame.mod.birb."..mapName..".scanned",false) ~= true then
        scanAll(true)
    else 
        G_cache = unserialize(GetString("savegame.mod.birb."..mapName..".gCache"))
        octtree = unserialize(GetString("savegame.mod.birb."..mapName..".octtree"))
    end

    

    RegisterListenerTo("requestPath","addPathtoQueue")
    queue = {}
    worker = {}
    worker.status = "free"
    worker.data = {}

    allowedMaxPerPath = 10
    vertecies = nil

    -- Debug stuff 

    drawlist = {}
end

function tick(dt)
    if InputDown("c") and InputDown("l") then ClearKey("savegame.mod.birb."..mapName) end
    if InputDown("c") and InputDown("l") and InputDown("a") then ClearKey("savegame.mod.birb") end
    queueWorker(dt)
    debugDraw()
end

function debugDraw()
    for i=1,#drawlist do 
        -- AutoTooltip(math.ceil(drawlist[i].cost),drawlist[i].pos[1],false,10,1)
         DebugLine(drawlist[i].pos[1],drawlist[i].pos[2],1,0,1,0.4)
     end
end

------------------------------- Queue System + path api ----------------------------

function queueWorker(dt)
    local maxWorkPerTick = 50
    if worker.status == "free" and #queue ~= 0 then 
        drawlist = {}
        worker.data = queue[1]
        table.remove(queue,1)
        worker.status = "busy"
        worker.result = {}
        worker.busyTimer = 0
    end
    if worker.status == "busy" then 
    --    AutoInspectWatch(worker,"worker",1," ",false)
        worker.busyTimer = worker.busyTimer + dt 
        for i=1, maxWorkPerTick do 
            coroutine.resume(starRoutine,worker.data.startPos,worker.data.endPos)
            if coroutine.status(starRoutine) == "dead" then 
                starRoutine = coroutine.create(aStar)
                drawlist = {}
                worker.status = "done"
                break
            end
        end
    end

    if worker.status == "done" then 
        local data = {}
        data.id = worker.data.id
        data.path = {}
        for i=1,#worker.result do 
            data.path[#data.path+1] = {}
            data.path[#data.path].pos = G_cache[worker.result[i]].pos
            data.path[#data.path].min = G_cache[worker.result[i]].min
            data.path[#data.path].max = G_cache[worker.result[i]].max
        end
        local dataString = serialize(data)
        local listener = "pathRecieve"..data.id

        AutoInspectWatch(worker,"data",1," ",0.01)
        TriggerEvent(listener,dataString)

        worker.status = "free"
    end
end

function addPathtoQueue(dataString)
    local data = unserialize(dataString)

    local index = #queue+1
    queue[index] = {}
    queue[index].status = {}
    queue[index].startPos = data.startPos 
    queue[index].endPos = data.endPos
    queue[index].id = data.id
end

------------------------------- Path Finding -------------------------------

function aStar(startPoint, endPoint)
    local function fCost(node)
        return node.gCost + node.hCost
    end

    local VecSub = VecSub 
    local VecLength = VecLength

    local coroutine_yield = coroutine.yield


    local startNodeIndex = closestNode(startPoint)
    local endNodeIndex = closestNode(endPoint)

   -- DebugLine(startPoint, G_cache[startNodeIndex].pos, 1, 0, 1, 1)
   -- DebugLine(endPoint, G_cache[endNodeIndex].pos, 1, 0, 1, 1)

    local walked = {}
    local openNodes = {}

    local startingDistance = AutoVecDist(G_cache[startNodeIndex].pos, G_cache[endNodeIndex].pos)
    if startingDistance < 75 then startingDistance = 100 end -- This is a modifier that makes the algo search through larger octtrees. But if its too close it will never be able to pin point the goal
    local curDistModifier = 1

    openNodes[startNodeIndex] = { gCost = 0, hCost = startingDistance  }
    local closedNodes = {}

    local endNode = G_cache[endNodeIndex]
    
   -- local superCost
   -- if InputDown("l") then superCost = 0 else superCost = 1 end

    local lowestCost = {}
    lowestCost.index = 0
    lowestCost.cost = 1000000

    while next(openNodes) ~= nil do
        local curNodeIndex, currentNode = next(openNodes)
        for index, costs in pairs(openNodes) do
            local fCostCurrent = fCost(currentNode)
            local fCostOther = fCost(costs)

            if fCostOther < fCostCurrent or (fCostCurrent == fCostOther and currentNode.gCost < costs.gCost ) then
                currentNode = openNodes[index]
                curNodeIndex = index
                if lowestCost.cost > fCostOther then 
                    lowestCost.cost = fCostOther
                    lowestCost.index = index
                end
            end
        end

        closedNodes[curNodeIndex] = true
        openNodes[curNodeIndex] = nil

        if curNodeIndex == endNodeIndex or worker.busyTimer > allowedMaxPerPath then
            if worker.busyTimer > allowedMaxPerPath then 
                worker.result = retracePath(walked, startNodeIndex, lowestCost.index)
                DebugPrint("triggered")
            else 
                worker.result = retracePath(walked, startNodeIndex, endNodeIndex)
            end
            return 
        end

        local cacheVal = G_cache[curNodeIndex]
        curDistModifier = AutoVecDist(cacheVal.pos, G_cache[endNodeIndex].pos)/startingDistance

        for i = 1, #cacheVal.nearby do
            local neighborIndex = cacheVal.nearby[i]
            local neighbor = G_cache[neighborIndex]

            if neighbor.cost ~= -1 and not closedNodes[neighborIndex] then
                local posDiff = VecNormalize(VecSub(neighbor.pos, cacheVal.pos))
                local costToNext = currentNode.gCost + math.max(VecDot(posDiff,VecNormalize(VecSub(endNode.pos,cacheVal.pos))),0) + neighbor.cost*curDistModifier--*superCost
                if not openNodes[neighborIndex] or costToNext < openNodes[neighborIndex].gCost then
                    local newNeighbor = {
                        gCost = costToNext,
                        hCost = AutoVecDist(neighbor.pos, endNode.pos),
                        parent = curNodeIndex
                    }

                    drawlist[#drawlist+1] = {}
                    drawlist[#drawlist].pos = {}
                    drawlist[#drawlist].pos[1] = G_cache[neighborIndex].pos
                    drawlist[#drawlist].pos[2] = G_cache[curNodeIndex].pos
                  -- DebugLine(G_cache[curNodeIndex].pos,G_cache[neighborIndex].pos)

                    coroutine_yield()

                    openNodes[neighborIndex] = newNeighbor
                    walked[neighborIndex] = newNeighbor
                end
            end
        end
    end

    return retracePath(walked, startNodeIndex, endNodeIndex)
end

function retracePath(openNodes, startNode, endNode)
    local wayPoints = {}
    local currentNode = endNode

    while currentNode ~= startNode and openNodes[currentNode] ~= nil do
        wayPoints[#wayPoints + 1] = currentNode
        currentNode = openNodes[currentNode].parent
    end

    wayPoints[#wayPoints + 1] = startNode
    return wayPoints
end

------------------------------- Terrain Scanning and node graph Building -------------------------------

function scanAll(debugMode)
    if not debugMode then debugMode = false end
    local min,max = GetBodyBounds(GetWorldBody())
    local minX,maxX = min[1],max[1]
    local minY,maxY = min[2],max[2]
    local minZ,maxZ = min[3],max[3]

    --for i=1,#list do 
    --    cacheSort[i] = {}
    --end
    local octtreeSize = 32

    local xi,yi,zi = 0,0,0
    --DebugLine(GetBodyTransform(checkShape[1].body).pos)
    for x=minX,maxX,octtreeSize do
        for y=minY,maxY,octtreeSize do 
            for z=minZ,maxZ,octtreeSize do
                globalt= Transform(Vec(x,y,z))

                cache = {}
                cache = recursiveSearch(cache,globalt,1,globalt)

                local oMin,oMax = GetBodyBounds(list[1])

                local index = #octtree+1
                octtree[index] = {}
                --octtree[index].min = oMin
                --octtree[index].max = oMax
                octtree[index].pos = VecLerp(oMin,oMax,0.5)
                octtree[index].members = {} 

                for i=1,#cache do 
                    if cache[i].cost ~= -1 then         -- This step seems to be a little slow actually. Not sure if it would have been faster to create G_cache during recursiveSearch() itself
                        local gIndex = #G_cache+1
                        G_cache[gIndex] = {}
                        G_cache[gIndex].cost = cache[i].cost
                        local cmin = cache[i].min
                        local cmax = cache[i].max
                        G_cache[gIndex].min   = cmin
                        G_cache[gIndex].max   = cmax
                        G_cache[gIndex].pos   = cache[i].pos
                        G_cache[gIndex].faces = {}
                        G_cache[gIndex].faces.up = {min = {cmin[1], cmax[2], cmin[3]}, max = cmax}
                        G_cache[gIndex].faces.down = {min = cmin, max = {cmax[1], cmin[2], cmax[3]}}
                        G_cache[gIndex].faces.left = {min = cmin, max = {cmin[1], cmax[2], cmax[3]}}
                        G_cache[gIndex].faces.right = {min = {cmax[1], cmin[2], cmin[3]}, max = cmax}
                        G_cache[gIndex].faces.forward = {min = cmin, max = {cmax[1], cmax[2], cmin[3]}}
                        G_cache[gIndex].faces.backward = {min = {cmin[1], cmin[2], cmax[3]}, max = cmax}
                        G_cache[gIndex].nearby = {}
                        --cacheSort[cache[i].depth][#cacheSort[cache[i].depth]+1] = #G_cache

                        octtree[index].members[#octtree[index].members+1] = gIndex
                    end
                end
                zi = zi + octtreeSize
            end
            yi = yi + octtreeSize
        end
        xi = xi + octtreeSize
    end

    calculateGrid()         -- This part is very memory intensive. It can spike ram usage up  to 16 at its peak 
    determinNeighbours()
    
    -- determinNeighboursOld()

    --ClearKey("savegame.mod.birb")
    if debugMode then
        for i=1,#G_cache do 
            G_cache[i].faces = nil
        end
        local str = serialize(G_cache)
        SetBool("savegame.mod.birb."..mapName..".scanned",true)
        SetString("savegame.mod.birb."..mapName..".gCache",str)

        local str = serialize(octtree)
        SetString("savegame.mod.birb."..mapName..".octtree",str)
    end

    for i=1,#checkShape do 
        SetBodyTransform(checkShape[i].body,Transform(Vec(0,100000,0)))
    end
end

function recursiveSearch(cache,t,depth,mainBodyT)
    SetBodyTransform(checkShape[depth].body,t)                      -- This octtree checker works by moving a giant shape 
    local cost = math.pow(2,depth)/2                                -- We do a queryaabb and see if there are any shapes in its bounds
    for i=1, #checkShape[depth].shapes do                           -- After that we do a is a shape touching check. This is done because 
        QueryRequire("physical visible")                            -- Queryaabb is a simple bounds check and cylinder shapes inside would still count as occupied 
        local min,max = GetShapeBounds(checkShape[depth].shapes[i]) 
        local shapes = QueryAabbShapes(min,max)
        if #shapes == 0 then
           calculateCost(AutoVecRound(min),AutoVecRound(max),cache,cost,depth)  -- If no shape was found we give it a cost of the current depth
        else                                                                    -- Cost is used to incourage a* to path find through larger octtree blocks 
            local none = true
            for j=1,#shapes do 
                if IsShapeTouching(checkShape[depth].shapes[i],shapes[j]) then
                    if depth ~= #checkShape then
                        cache = recursiveSearch(cache,GetShapeWorldTransform(checkShape[depth].shapes[i]),depth + 1,mainBodyT)
                    end
                    none = false 
                    break 
                end 
            end
            if none == true then 
                calculateCost(AutoVecRound(min),AutoVecRound(max),cache,cost,depth)
            elseif depth == #checkShape then
                calculateCost(AutoVecRound(min),AutoVecRound(max),cache,-1,depth)   -- -1 means this is not navigatable
            end
        end
    end
    return cache
end

function calculateCost(min,max,cache,cost,depth)
    local index = #cache+1
    cache[index] = {}

    cache[index].cost = cost
    cache[index].min = min
    cache[index].max = max
    cache[index].pos = VecLerp(min,max,0.5)
  --  if  IsPointInWater(cache[index].pos) then cache[index].cost = -1 end
    cache[index].depth = depth
    return cache
end

function calculateGrid()
    for index=1,#G_cache do
        local faces = G_cache[index].faces
        for dir,p in pairs(faces) do --p as in point either min or max
            for x=p.min[1],p.max[1],1 do 
                if not vertecies[x] then vertecies[x] = {} end
                for y=p.min[2],p.max[2],1 do 
                    if not vertecies[x][y] then vertecies[x][y] = {} end
                    for z=p.min[3],p.max[3],1 do
                        if not vertecies[x][y][z] then vertecies[x][y][z] = {} end
                      --  if not isNumberInTable(vertecies[x][y][z],index) then
                        vertecies[x][y][z][#vertecies[x][y][z]+1] = index
                    --    end
                    end
                end
            end
        end
    end
end

function determinNeighbours()
   -- count = 1
    for index = 1, #G_cache do              -- This stores all octtree data
        local faces = G_cache[index].faces  -- We save all faces of the octtree boxes
        for dir, points in pairs(faces) do  -- Each face stores the min and max of the face 
            local exit = false              -- Optimisation
            local results = {}
           -- local vert = calculateFaceCorners(p.min, p.max)
            for _,point in pairs(points) do 
                local x, y, z = point[1], point[2], point[3] -- To determin all neighbours near a box we build a completly new table
                local values = vertecies[x][y][z]            -- This 3D table stores all G_cache ids at the mins and max of the faces
                for v = 1, #values do                        -- To find a neighbour we check at vertex[min] and see which box shares it as well
                   -- count = count + 1                      -- We check if we find an id more than once its a neighbour - Current implementaion does not support diagonal neighbour search
                    local vertex = values[v]                 -- vertex is the G_cache id of other octtree boxes
                    if not results[vertex] then         
                        results[vertex] = 1                  -- Instead of having an unsorted table we do result[id] = how often it was found
                    else
                        results[vertex] = results[vertex] + 1
                        if results[vertex] == 2 and not isNumberInTable(G_cache[index].nearby, vertex) then
                            G_cache[index].nearby[#G_cache[index].nearby + 1] = vertex
                            exit = true
                            if not isNumberInTable(G_cache[vertex].nearby,index) then          -- When we found a neighbour we write it in our .nearby table but also in the others box
                                G_cache[vertex].nearby[#G_cache[vertex].nearby + 1] = index    -- This is done because small octtree boxes can be in the middle of a largers boxes face
                            end                                                                -- The large box cannot find the smaller boxes though therefor we write it in the others table too we just need to check that this doesnt happen twice
                        end
                    end
                end
                if exit then
                    break
                end
            end
        end
    end
  --  DebugPrint(count)
end

---------------------------------- Helper Functions -----------------------------------------
function pointInBox(point, minPoint, maxPoint)
    for i = 1, 3 do
        if point[i] < minPoint[i] or point[i] > maxPoint[i] then
            return false
        end
    end
    return true
end

function isNumberInTable(table, targetNumber)
    for _, value in ipairs(table) do
        if value == targetNumber then
            return true  -- Number is found in the table
        end
    end
    return false  -- Number is not found in the table
end

function removeForwardSlashes(inputString)
    local afterColon = inputString:match(":(.*)")
    if afterColon then
        -- Remove any forward slashes in the part after the colon
        local cleanedString = afterColon:gsub("/", "")
        -- Ensure that everything after the colon is alphanumeric
        local resultString = cleanedString:gsub("[^%w]", "")
        return resultString
    else
        -- If no colon is found, remove only the forward slashes from the entire input string
        return inputString:gsub("/", "")
    end
end

function closestNode(point) -- Pile of trash

    local gP = closestGroup(point) -- gP = Group Index 
    local members = octtree[gP].members     -- During the creation process of the node graph we remember in which octtree each node was build/used to scan
                                            -- We put the nodes in a group together. Before we do a scan which node is the actuall closest we first check
    local index = 0                         -- Which Group is closest and only then perform the distance check on the nodes itself
    local cloesestDist = 10000              -- This lowers lag from 16 ms (depending on the map) to barely noticable


    for i=1,#members do
        local cacheIndex = members[i]
        if G_cache[cacheIndex].cost ~= -1 then
            local dist = AutoVecDist(point, G_cache[cacheIndex].pos)
            if dist < cloesestDist then
                cloesestDist = dist
                index = cacheIndex
            end
        end
    end
    return index
end

function closestGroup(point) -- Pile of trash
    local index = 0
    local cloesestDist = 10000
    for i=1,#octtree do
        local dist = AutoVecDist(point, octtree[i].pos)
        if dist < cloesestDist then
            cloesestDist = dist
            index = i
        end
    end
    return index
end
