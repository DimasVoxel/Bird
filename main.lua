--[[
#include /script/Automatic.lua
#include /script/registry.lua
#include /script/lualzw.lua
]]--

-- Local is faster than global
--local cacheSort = {}



--local spatialSort = {}

function init()
    initDone = false
    initialize = coroutine.create(start)
    perTickLimit = 300

    showVisuals = true 
end

function start()

    checkShape = {}
    vertecies = {}
    G_cache = {}
    octGroup = {} 

    compressRegistry = false
    starRoutine = coroutine.create(aStar)

  --  Spawn("MOD/client.xml",Transform())
    Spawn('<script pos="0.0 0.2 0.0" file="MOD/spawnbird.lua"/>',Transform())
    mapName = removeForwardSlashes(GetString("game.levelpath"))
    if GetBool("savegame.mod.birb."..mapName..".scanned",false) ~= true then
        initCheckShape()
        scanAll(true)

        vertecies = nil
        collectgarbage("collect")
    else
        if compressRegistry then
            retrieveCompressedData()
        else
            retrieveData() 
        end
    end

    
    print("Final cleanup and API setup\n")
    progressMessage = "Final cleanup and API setup\n"
    RegisterListenerTo("requestPath","addPathtoQueue")

    queue = {}
    worker = {}
    worker.status = "free"
    worker.data = {}

    allowedMaxTimePerPath = 8

    drawlist = {}
    initDone = true 
    progressMessage = ""
end

function initCheckShape()
    Spawn("MOD/boxes.xml",Transform())
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
end

function retrieveData() 
    print("Retrieving Cache Chunk data: ")

    local chunks = {}
    local keys = ListKeys("savegame.mod.birb."..mapName..".gCache")
    for i=1,#keys do 
        print("G_cache Chunk: "..i.." out of "..#keys)
        chunks[#chunks+1] = unserialize(GetString("savegame.mod.birb."..mapName..".gCache."..keys[i]))
    end

    G_cache = combineTableChunks(chunks)

    local chunks = {}
    local keys = ListKeys("savegame.mod.birb."..mapName..".octGroup")
    for i=1,#keys do 
        print("octGroup Chunk: "..i.." out of "..#keys)
        chunks[#chunks+1] = unserialize(GetString("savegame.mod.birb."..mapName..".octGroup."..keys[i]))
    end

    octGroup = combineTableChunks(chunks)
end

function retrieveCompressedData()
    print("Retrieving Cache Chunk data: ")
    local chunks = {}
    local keys = ListKeys("savegame.mod.birb."..mapName..".gCache")
    for i=1,#keys do 
        print("G_cache Chunk: "..i.." out of "..#keys)

        local compressedBrokenString = GetString("savegame.mod.birb."..mapName..".gCache."..keys[i])
        local compressedString = loadstring('return ' ..compressedBrokenString)()
        chunks[#chunks+1] = unserialize(decompress(compressedString))
    end

    G_cache = combineTableChunks(chunks)

    local chunks = {}
    local keys = ListKeys("savegame.mod.birb."..mapName..".octGroup")
    for i=1,#keys do 
        print("octGroup Chunk: "..i.." out of "..#keys)
        local compressedBrokenString = GetString("savegame.mod.birb."..mapName..".octGroup."..keys[i])
        local compressedString = loadstring('return ' ..compressedBrokenString)()
        chunks[#chunks+1] = unserialize(decompress(compressedString))
    end

    octGroup = combineTableChunks(chunks)
end

function tick(dt)
    if initDone == false then
        if InputPressed("return") then 
            showVisuals = not showVisuals
        end
        for i=0,perTickLimit do
            coroutine.resume(initialize)
        end
    else
        if InputDown("c") and InputDown("l") then ClearKey("savegame.mod.birb."..mapName) end
        if InputDown("c") and InputDown("l") and InputDown("a") then ClearKey("savegame.mod.birb") end
        queueWorker(dt)
        debugDraw()
    end
end

function debugDraw()
    if InputDown("k") then
    for i=1,#drawlist do 
        -- AutoTooltip(math.ceil(drawlist[i].cost),drawlist[i].pos[1],false,10,1)
         DebugLine(drawlist[i].pos[1],drawlist[i].pos[2],1,0,1,0.4)
     end
    end
end

------------------------------- Terrain Scanning and node graph Building -------------------------------

function scanAll(cacheToRegistry)
    print("Start scanning process...")
    progressMessage = "Start scanning process..."
    if not cacheToRegistry then cacheToRegistry = false end
    local min,max = GetBodyBounds(GetWorldBody())
    local minX,maxX = min[1],max[1]
    local minY,maxY = min[2],max[2]
    local minZ,maxZ = min[3],max[3]
    local octtreeSize = 32

    local totalIterations = math.floor((maxX - minX) / octtreeSize + 1) * math.floor((maxY - minY) / octtreeSize + 1) * math.floor((maxZ - minZ) / octtreeSize +1 )

    local currentIteration = 0

    local xi,yi,zi = 0,0,0
    --DebugLine(GetBodyTransform(checkShape[1].body).pos)
    for x=minX,maxX,octtreeSize do
        for y=minY,maxY,octtreeSize do 
            for z=minZ,maxZ,octtreeSize do
                globalt= Transform(Vec(x,y,z))

                cache = {}
                cache = recursiveSearch(cache,globalt,1,globalt)

                local oMin,oMax = GetBodyBounds(list[1])

                local index = #octGroup+1
                octGroup[index] = {}
                --octGroup[index].min = oMin
                --octGroup[index].max = oMax
                octGroup[index].pos = VecLerp(oMin,oMax,0.5)
                octGroup[index].group = {} 

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

                        octGroup[index].group[#octGroup[index].group+1] = gIndex
                        
                    end
                end
                
                currentIteration = currentIteration + 1
                local progress = (currentIteration / totalIterations) * 100
                print("Progress: " .. math.ceil(progress) .. "%")
                progressMessage = "Progress: " .. math.ceil(progress) .. "%"
                SetString("level.loadingMessage",math.ceil(progress) .. "%")
            end
        end
    end
    print("Scan Complete\n")
    progressMessage = "Scan Complete\n"
   -- AutoInspectWatch(octGroup," asd",1 ," ")
    perTickLimit = 4000
    calculateGrid() 
    perTickLimit = 1000
    determinNeighbours()
    perTickLimit = 1
    -- determinNeighboursOld()

    --ClearKey("savegame.mod.birb")
    if cacheToRegistry then
        if compressRegistry then
            writeCarcheCompressed()
        else
            writeCache()
        end
    end

    for i=1,#checkShape do 
        SetBodyTransform(checkShape[i].body,Transform(Vec(0,100000,0)))
    end
end


function writeCarcheCompressed()
    print("Caching results\n")
    progressMessage = "Caching results\n"

    local tableChunks = splitTable(G_cache,100000)
    for i=1,#tableChunks do 
        print("Preparing G_cache table for caching: "..math.floor(i/#tableChunks*100).."%")
        progressMessage = "Preparing G_cache table for caching: "..math.floor(i/#tableChunks*100).."%"
        coroutine.yield()
        local serializeTableString = serialize(tableChunks[i])
        local compressedString = string.format('%q',compress(serializeTableString))

        SetString("savegame.mod.birb."..mapName..".gCache."..i,compressedString) -- This part is very memory intensive. It can spike ram usage up to 16gb at its peak depending on the map
    end
    
    local tableChunks = splitTable(octGroup,30)
    for i=1,#tableChunks do 
        coroutine.yield()
        print("Preparing octGroup table for caching: "..math.floor(i/#tableChunks*100).."%")
        progressMessage = "Preparing octGroup table for caching: "..math.floor(i/#tableChunks*100).."%"

        local serializeTableString = serialize(tableChunks[i])
        local compressedString = string.format('%q',compress(serializeTableString))

        SetString("savegame.mod.birb."..mapName..".octGroup."..i,compressedString) -- This part is very memory intensive. It can spike ram usage up to 16gb at its peak depending on the map
    end

    SetBool("savegame.mod.birb."..mapName..".scanned",true)
end

function writeCache()
        print("Caching results\n")

        local tableChunks = splitTable(G_cache,20000)
        for i=1,#tableChunks do 
            coroutine.yield()
            print("Preparing G_cache table for caching: "..math.floor(i/#tableChunks*100).."%")
            progressMessage = "Preparing G_cache table for caching: "..math.floor(i/#tableChunks*100).."%"
            SetString("savegame.mod.birb."..mapName..".gCache."..i,serialize(tableChunks[i])) -- This part is very memory intensive. It can spike ram usage up to 16gb at its peak depending on the map
        end
        
        local tableChunks = splitTable(octGroup,25)
        for i=1,#tableChunks do 
            coroutine.yield()
            print("Preparing octGroup table for caching: "..math.floor(i/#tableChunks*100).."%")
            progressMessage = "Preparing octGroup table for caching: "..math.floor(i/#tableChunks*100).."%"
            SetString("savegame.mod.birb."..mapName..".octGroup."..i,serialize(tableChunks[i])) -- This part is very memory intensive. It can spike ram usage up to 16gb at its peak depending on the map
        end
        coroutine.yield()
        SetBool("savegame.mod.birb."..mapName..".scanned",true)
end

function recursiveSearch(cache,t,depth,mainBodyT)
    coroutine.yield()
    SetBodyTransform(checkShape[depth].body,t)                      -- This octtree checker works by moving a giant shape 
    local cost = math.pow(2,depth)/2                                -- We do a queryaabb and see if there are any shapes in its bounds
    for i=1, #checkShape[depth].shapes do                           -- After that we do a is a shape touching check. This is done because 
        QueryRequire("physical visible")                            -- Queryaabb is a simple bounds check and cylinder shapes inside would still count as occupied 
        local min,max = GetShapeBounds(checkShape[depth].shapes[i]) 
        local shapes = QueryAabbShapes(min,max)
        if showVisuals then
            AutoDrawAABB(min,max)
        end
        
        if #shapes == 0 then
           calculateCost(AutoVecRound(min),AutoVecRound(max),cache,cost,depth)  -- If no shape was found we give it a cost of the current depth
        else                                                                    -- Cost is used to incourage a* to path find through larger octtree blocks 
            local none = true
            if IsPointInWater(min) then 
                if depth ~= #checkShape then
                    cache = recursiveSearch(cache,GetShapeWorldTransform(checkShape[depth].shapes[i]),depth + 1,mainBodyT)
                end
                none = false 
            else
                for j=1,#shapes do 
                    if IsShapeTouching(checkShape[depth].shapes[i],shapes[j]) then
                        if depth ~= #checkShape then
                            cache = recursiveSearch(cache,GetShapeWorldTransform(checkShape[depth].shapes[i]),depth + 1,mainBodyT)
                        end
                        none = false 
                        break 
                    end 
                end
            end
            if none == true then 
                calculateCost(AutoVecRound(min),AutoVecRound(max),cache,cost,depth)
           -- elseif water then 
           --     calculateCost(AutoVecRound(min),AutoVecRound(max),cache,-2,depth)
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
    cache[index].depth = depth
    return cache
end

function calculateGrid()
    print("Creating Neighbour grid...")
    progressMessage = "Creating Neighbour grid..."
    for index=1,#G_cache do
        local faces = G_cache[index].faces
        for dir,p in pairs(faces) do --p as in point either min or max
            for x=p.min[1],p.max[1],1 do 
                if not vertecies[x] then vertecies[x] = {} end
                for y=p.min[2],p.max[2],1 do 
                    if not vertecies[x][y] then vertecies[x][y] = {} end
                    for z=p.min[3],p.max[3],1 do
                        if showVisuals then
                        DebugCross(G_cache[index].pos)
                        end
                        if not vertecies[x][y][z] then vertecies[x][y][z] = {} end
                      --  if not isNumberInTable(vertecies[x][y][z],index) then
                        vertecies[x][y][z][#vertecies[x][y][z]+1] = index
                    --    end
                    end
                end
            end
        end
        
        coroutine.yield()
    end
    print("...Grid Completed\n")
    progressMessage = "Creating Neighbour grid..."
end

function determinNeighbours()
   -- count = 1
    print("Finding neighbours...")
    progressMessage = "Finding neighbours..."
    
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
                    if values[v] ~= index then
                    -- count = count + 1                      -- We check if we find an id more than once its a neighbour - Current implementaion does not support diagonal neighbour search
                        local vertex = values[v]                 -- vertex is the G_cache id of other octtree boxes
                        if not results[vertex] then         
                            results[vertex] = 1                  -- Instead of having an unsorted table we do result[id] = how often it was found
                        else
                            
                            results[vertex] = results[vertex] + 1
                            if results[vertex] == 2 and not isNumberInTable(G_cache[index].nearby, vertex) then -- A value of == 1 can access all 24 diagonals, == 2 means a node graph that has access to diagonals 12 dirs, == 4 can only move up down fwd back left right
                                G_cache[index].nearby[#G_cache[index].nearby + 1] = vertex
                                exit = true
                                if showVisuals then
                                    DebugLine(G_cache[index].pos,G_cache[vertex].pos)
                                end
                                
                                if not isNumberInTable(G_cache[vertex].nearby, index) then          -- When we found a neighbour we write it in our .nearby table but also in the others box
                                    G_cache[vertex].nearby[#G_cache[vertex].nearby + 1] = index    -- This is done because small octtree boxes can be in the middle of a largers boxes face
                                end                                                                -- The large box cannot find the smaller boxes though therefor we write it in the others table too we just need to check that this doesnt happen twice
                            end
                        end
                    end
                end
                if exit then
                    break
                end
            end
        end
        
        coroutine.yield()
    G_cache[index].faces = nil
    end
    print("...Node graph completed\n")
    progressMessage = "...Node graph completed\n"
  --  Debugprint(count)
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
        if #queue == 0 then 
            worker.busyTimer = worker.busyTimer + dt/1.5
        else 
            worker.busyTimer = worker.busyTimer + dt 
        end
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
        data.startPos = worker.data.startPos
        data.endPos = worker.data.endPos
        local dataString = serialize(data)
        local listener = "pathRecieve"..data.id

        if #data.path == 0 or data.path == nil then
            data.status = "error"
            TriggerEvent(listener,dataString)
        else
            data.status = "success"
         --   print(dataString)
         --   print(data.id.."\n\n")
            TriggerEvent(listener,dataString)
        end
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
        return node.gCost + node.hCost + node.upCost
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

    openNodes[startNodeIndex] = { stepCounter = 0,upCost = -1, gCost = 0, hCost = startingDistance  }
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

        if curNodeIndex == endNodeIndex or worker.busyTimer > allowedMaxTimePerPath then
            if worker.busyTimer > allowedMaxTimePerPath then 
                worker.result = retracePath(walked, startNodeIndex, lowestCost.index)
                print("Path aborted too long")
            else 
                worker.result = retracePath(walked, startNodeIndex, endNodeIndex)
            end
            return 
        end

        local cacheVal = G_cache[curNodeIndex]
        curDistModifier = AutoVecDist(cacheVal.pos, G_cache[endNodeIndex].pos)/startingDistance
        
        for i = 1, #cacheVal.nearby do
            local neighbourIndex = cacheVal.nearby[i]
            local neighbour = G_cache[neighbourIndex]

            if neighbour.cost ~= -1 and not closedNodes[neighbourIndex] then
                local dir = VecSub(neighbour.pos, cacheVal.pos)
                local posDiff = VecNormalize(dir)
                local dot = math.abs(VecDot(posDiff,Vec(0,1,0)))
                if not openNodes[neighbourIndex] then elevationChange = -2 else elevationChange = openNodes[neighbourIndex].upCost end
                --if not openNodes[neighbourIndex] then counter = 1 else counter = openNodes[neighbourIndex].stepCounter+0.05 end

                if dot < 0.4 then
                    elevationChange = elevationChange + 0.17
                else 
                    elevationChange = math.max(elevationChange-0.1,-1)
                end
                --Debugprint(elevationChange)

                local len = VecLength(dir)/3
                local costToNext = currentNode.gCost + math.max(VecDot(posDiff,VecNormalize(VecSub(endNode.pos,cacheVal.pos))),0) + neighbour.cost*curDistModifier + len*curDistModifier + dot*(10*math.max(curDistModifier,0.3))-(elevationChange*2)*curDistModifier --+ counter --*superCost
                --local costToNext = currentNode.gCost +  math.max(VecDot(posDiff,VecNormalize(VecSub(endNode.pos,cacheVal.pos))),0) + (neighbour.cost + len + dot * 10 * math.max(curDistModifier, 0.3) - elevationChange * 4) * curDistModifier
                coroutine_yield()
                if not openNodes[neighbourIndex] or costToNext < openNodes[neighbourIndex].gCost then
                    local newneighbour = {
                        gCost = costToNext,
                        hCost = AutoVecDist(neighbour.pos, endNode.pos),
                        parent = curNodeIndex,
                        upCost = elevationChange,
                        --stepCounter = counter
                    }

                   drawlist[#drawlist+1] = {}
                   drawlist[#drawlist].pos = {}
                   drawlist[#drawlist].pos[1] = G_cache[neighbourIndex].pos
                   drawlist[#drawlist].pos[2] = G_cache[curNodeIndex].pos
                  -- DebugLine(G_cache[curNodeIndex].pos,G_cache[neighbourIndex].pos)

                    

                    openNodes[neighbourIndex] = newneighbour
                    walked[neighbourIndex] = newneighbour
                end
            end
        end
    end
    worker.result = retracePath(walked, startNodeIndex, lowestCost.index)
end

function retracePath(openNodes, startNode, endNode)
    local function reverseTable(t)
        local reversedTable = {}
        local length = #t
        for i, v in ipairs(t) do
            reversedTable[length - i + 1] = v
        end
        return reversedTable
    end
    
    local wayPoints = {}
    local currentNode = endNode

    while currentNode ~= startNode and openNodes[currentNode] ~= nil do
        wayPoints[#wayPoints + 1] = currentNode
        currentNode = openNodes[currentNode].parent
    end

    wayPoints[#wayPoints + 1] = startNode



    return reverseTable(wayPoints)
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
    local members = octGroup[gP].group     -- During the creation process of the node graph we remember in which octtree each node was build/used to scan
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
    for i=1,#octGroup do
        local dist = AutoVecDist(point, octGroup[i].pos)
        if dist < cloesestDist then
            cloesestDist = dist
            index = i
        end
    end
    return index
end

function splitTable(inputTable, chunkSize)
    local resultTable = {}
    local currentIndex = 1

    for i = 1, #inputTable, chunkSize do
        local chunk = {}
        for j = i, math.min(i + chunkSize - 1, #inputTable) do
            chunk[j - i + 1] = inputTable[j]
        end
        resultTable[currentIndex] = chunk
        currentIndex = currentIndex + 1
    end

    return resultTable
end

function combineTableChunks(chunks)
    local resultTable = {}

    for _, chunk in ipairs(chunks) do
        for _, value in ipairs(chunk) do
            table.insert(resultTable, value)
        end
    end

    return resultTable
end

    function handleCommand(cmd)
        if cmd == "quickload" then
     --   G_cache = CACHE
        starRoutine = coroutine.create(aStar)
        RegisterListenerTo("requestPath","addPathtoQueue")
        end
    end

function draw()
    UiPush()
        UiTranslate(UiCenter(), UiHeight()-200)
        UiAlign("center")
        UiFont("bold.ttf", 24)
        UiText(progressMessage)
        UiTranslate(0,50)
        if not progressMessage == "" then
        UiText("Press return to show debug: ".. tostring(showVisuals))
        end
    UiPop()
end