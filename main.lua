--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

--[[
#include ./Birds/Automatic.lua
#include ./registry.lua

]]--

-- Local is faster than global
local G_cache = {}
local cacheSort = {}
local checkShape = {}
local vertecies = {}

function init()
    drawlist = {}
    finished = false
    starRoutine = coroutine.create(aStar)

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
    scanAll()

    targetBody = FindBody("targetObject",true)
    startBody = FindBody("startObject",true)

    startPos = Vec()
    endPos = Vec()

    path = {}
end

function scanAll(debugMode)
    if not debugMode then debugMode = false end
    local min,max = GetBodyBounds(GetWorldBody())
    local minX,maxX = min[1],max[1]
    local minY,maxY = min[2],max[2]
    local minZ,maxZ = min[3],max[3]
    local count = 0

    for i=1,#list do 
        cacheSort[i] = {}
    end
    local octtreeSize = 32

    local xi,yi,zi = 0,0,0
    DebugLine(GetBodyTransform(checkShape[1].body).pos)
    for x=minX,maxX,octtreeSize do
        for y=minY,maxY,octtreeSize do 
            for z=minZ,maxZ,octtreeSize do
                globalt= Transform(Vec(x,y,z))

                cache = {}
                cache = recursiveSearch(cache,globalt,1,globalt)

                for i=1,#cache do 
                    if cache[i].cost ~= -1 then
                    G_cache[#G_cache+1] = {}
                    G_cache[#G_cache].cost = cache[i].cost
                    local cmin = VecCopy(cache[i].min)
                    local cmax = VecCopy(cache[i].max)
                    G_cache[#G_cache].min   = cmin
                    G_cache[#G_cache].max   = cmax
                    G_cache[#G_cache].pos   = cache[i].pos
                    G_cache[#G_cache].faces = {}

                    -- Up face
                    G_cache[#G_cache].faces.up = {min = {cmin[1], cmax[2], cmin[3]}, max = cmax}
                    -- Down face
                    G_cache[#G_cache].faces.down = {min = cmin, max = {cmax[1], cmin[2], cmax[3]}}
                    -- Left face
                    G_cache[#G_cache].faces.left = {min = cmin, max = {cmin[1], cmax[2], cmax[3]}}
                    -- Right face
                    G_cache[#G_cache].faces.right = {min = {cmax[1], cmin[2], cmin[3]}, max = cmax}
                    -- Forward face
                    G_cache[#G_cache].faces.forward = {min = cmin, max = {cmax[1], cmax[2], cmin[3]}}
                    -- Backward face
                    G_cache[#G_cache].faces.backward = {min = {cmin[1], cmin[2], cmax[3]}, max = cmax}

                    G_cache[#G_cache].nearby = {}
                    cacheSort[cache[i].depth][#cacheSort[cache[i].depth]+1] = #G_cache
                end
            end
                zi = zi + octtreeSize
            end
            yi = yi + octtreeSize
        end
        xi = xi + octtreeSize
    end
    calculateGrid()
    determinNeighbours()

   -- determinNeighboursOld()

    ClearKey("savegame.mod.birb")
    if debugMode then
        local str = serialize(G_cache)
        SetString("savegame.mod.birb",str)
    end

    for i=1,#checkShape do 
        SetBodyTransform(checkShape[i].body,Transform(Vec(0,100000,0)))
    end
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
                        if not isNumberInTable(vertecies[x][y][z],index) then
                        vertecies[x][y][z][#vertecies[x][y][z]+1] = index
                        end
                    end
                end
            end
        end
    end
end

function determinNeighbours()
   -- count = 1
    for index = 1, #G_cache do
        local faces = G_cache[index].faces
        for dir, points in pairs(faces) do -- p as in point either min or max
            local exit = false
            local results = {}
           -- local vert = calculateFaceCorners(p.min, p.max)
            for _,point in pairs(points) do 
                local x, y, z = point[1], point[2], point[3]
                local values = vertecies[x][y][z]
                for v = 1, #values do
                   -- count = count + 1
                    local vertex = values[v]
                    if not results[vertex] then
                        results[vertex] = 1
                    else
                        results[vertex] = results[vertex] + 1
                        if results[vertex] == 2 and not isNumberInTable(G_cache[index].nearby, vertex) then
                            G_cache[index].nearby[#G_cache[index].nearby + 1] = vertex
                            exit = true
                            if not isNumberInTable(G_cache[vertex].nearby,index) then 
                                G_cache[vertex].nearby[#G_cache[vertex].nearby + 1] = index
                            end
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

function aStar(startPoint, endPoint)
    local function fCost(node)
        return node.gCost + node.hCost
    end

    local VecSub = VecSub 
    local VecLength = VecLength
    local G_cache = G_cache
    local coroutine_yield = coroutine.yield


    local startNodeIndex = closestNode(startPoint)
    local endNodeIndex = closestNode(endPoint)

    DebugLine(startPoint, G_cache[startNodeIndex].pos, 1, 0, 1, 1)
    DebugLine(endPoint, G_cache[endNodeIndex].pos, 1, 0, 1, 1)

    local walked = {}
    local openNodes = {}
    openNodes[startNodeIndex] = { gCost = 0, hCost = AutoVecDist(G_cache[startNodeIndex].pos, G_cache[endNodeIndex].pos) }
    local closedNodes = {}

    local endNode = G_cache[endNodeIndex]

    while next(openNodes) ~= nil do
        local curNodeIndex, currentNode = next(openNodes)
        for index, costs in pairs(openNodes) do
            local fCostCurrent = fCost(currentNode)
            local fCostOther = fCost(costs)

            if fCostOther < fCostCurrent or (fCostCurrent == fCostOther and currentNode.gCost < costs.gCost ) then
                currentNode = openNodes[index]
                curNodeIndex = index
            end
        end

        closedNodes[curNodeIndex] = true
        openNodes[curNodeIndex] = nil

        if curNodeIndex == endNodeIndex then
            path = retracePath(walked, startNodeIndex, endNodeIndex)
            return
        end

        local L_cache = G_cache[curNodeIndex]
        

        for i = 1, #L_cache.nearby do
            local neighborIndex = L_cache.nearby[i]
            local neighbor = G_cache[neighborIndex]

            if neighbor.cost ~= -1 and not closedNodes[neighborIndex] then
                local posDiff = VecNormalize(VecSub(neighbor.pos, L_cache.pos))
                local costToNext = currentNode.gCost + math.max(VecDot(posDiff,VecNormalize(VecSub(endNode.pos,L_cache.pos))),0)
                if not openNodes[neighborIndex] or costToNext < openNodes[neighborIndex].gCost then
                    local newNeighbor = {
                        gCost = costToNext,
                        hCost = AutoVecDist(neighbor.pos, endNode.pos),
                        parent = curNodeIndex
                    }

              --    drawlist[#drawlist+1] = {}
              --    drawlist[#drawlist].pos = {}
              --  --  drawlist[#drawlist].cost = fCost(neighbor)
              --    drawlist[#drawlist].pos[1] = G_cache[neighborIndex].pos
              --    drawlist[#drawlist].pos[2] = G_cache[curNodeIndex].pos
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


function worldPointToCache(point)
    for index=1,#G_cache do 
        if pointInBox(point,G_cache[index].min,G_cache[index].max) then
            return index
        end
    end
end

function closestNode(point)
    local index = 0
    local cloesestDist = 10000
    for i=1,#G_cache do
        if G_cache[i].cost ~= -1 then
            local dist = AutoVecDist(point, G_cache[i].pos)
            if dist < cloesestDist then
                cloesestDist = dist
                index = i
            end
        end
    end
    return index
end

function pointAndfind()
    local p = GetPlayerPos()
    AutoDrawAABB(GetBodyBounds(GetWorldBody()))
    DebugLine(GetBodyTransform(startBody).pos,GetBodyTransform(targetBody).pos)

    local t = GetPlayerCameraTransform()
    local fwd = TransformToParentVec(t,Vec(0,0,-1))

    local hit,dist = QueryRaycast(t.pos,fwd,50)
    local hitPoint = VecAdd(t.pos,VecScale(fwd,dist))

    if InputPressed("u") then 
        startPos = VecCopy(hitPoint)
    end
    if InputPressed("i") then 
        endPos = VecCopy(hitPoint)
    end
    DebugLine(startPos,endPos)

    if InputDown("return") and finished == false then

        for i=1, 100 do 
            coroutine.resume(starRoutine,startPos,endPos)
            if coroutine.status(starRoutine) == "dead" then 
                starRoutine = coroutine.create(aStar)
                drawlist = {}
                finished = true
                break
            end
        end
    end

    if InputReleased("return") and finished == true then finished = false end
    
    if InputPressed("k") then drawlist = {} starRoutine = coroutine.create(aStar) end
    for i=1,#drawlist do 
       -- AutoTooltip(math.ceil(drawlist[i].cost),drawlist[i].pos[1],false,10,1)
        DebugLine(drawlist[i].pos[1],drawlist[i].pos[2],1,0,1,0.4)
    end

    for i=1,#path do 
        if i == #path then 
            break
        end 
        DebugLine(G_cache[path[i]].pos,G_cache[path[i+1]].pos)
    end
end

function blocksearch() -- uses two cubes to find the best path between those two
    --InputPressed("o") then 
      --  path = aStar(GetBodyTransform(targetBody).pos,GetBodyTransform(startBody).pos)
      local targetPos = GetBodyTransform(targetBody).pos
      local startBody = GetBodyTransform(startBody).pos
    for i=1, 20 do 
        coroutine.resume(starRoutine,targetPos,startBody)
        if coroutine.status(starRoutine) == "dead" then 
            starRoutine = coroutine.create(aStar)
            break
        end
    end

    for i=1,#drawlist do 
        -- AutoTooltip(math.ceil(drawlist[i].cost),drawlist[i].pos[1],false,10,1)
         DebugLine(drawlist[i].pos[1],drawlist[i].pos[2],1,0,1,0.4)
     end

    for i=1,#path do 
        if i == #path then 
            break
        end 
        DebugLine(G_cache[path[i]].pos,G_cache[path[i+1]].pos)
    end
    if coroutine.status(starRoutine) == "dead" then 
        drawlist = {}
    end
end

function draw(dt)
    pointAndfind()
 --   blocksearch()
  --  determinNeighbours()
  -- count = 1


  -- debug()
end

function recursiveSearch(cache,t,depth,mainBodyT)
    SetBodyTransform(checkShape[depth].body,t)
    local cost = math.pow(2,depth)/2
    for i=1, #checkShape[depth].shapes do
        QueryRequire("physical visible")
        local min,max = GetShapeBounds(checkShape[depth].shapes[i])
        local shapes = QueryAabbShapes(min,max)
        if #shapes == 0 then
           calculateCost(AutoVecRound(min),AutoVecRound(max),cache,cost,depth)
        else
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
                calculateCost(AutoVecRound(min),AutoVecRound(max),cache,-1,depth)
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



function debug()
     --   local p = GetPlayerPos()
 ----recursiveSearch(cache,globalt,depth,globalt)
    for j=1,#cacheSort do 
        local indexi = j
        for i=1,#cacheSort[indexi] do 
            local index = cacheSort[indexi][i]
             if G_cache[index].cost ~= -1 then
            --ids[#ids+1] = cacheAll[x][y][z].id
            --AutoTooltip(cacheAll[x][y][z].cost,cacheAll[x][y][z].pos,false,2,1)
            --DebugLine(G_cache[index].min,G_cache[index].max,0,0,0,1)
              AutoDrawAABB(G_cache[index].min,G_cache[index].max,0,0,0,0.1)
            --DebugLine(G_cache[cacheSort[indexi][i]].pos,VecAdd(G_cache[cacheSort[indexi][i]].pos,Vec(0,G_cache[cacheSort[indexi][i]].max[2]-G_cache[cacheSort[indexi][i]].min[2],0)))

        --      for i=1,#G_cache[index].nearby do 
        --          local otherPos = G_cache[G_cache[index].nearby[i]].pos
        --          DebugLine(G_cache[index].pos,otherPos,1,1,1,1)
        --      end
        --  else
        --      for i=1,#G_cache[index].nearby do 
        --          local otherPos = G_cache[G_cache[index].nearby[i]].pos
        --          DebugLine(G_cache[index].pos,otherPos,1,0,0,0.2)
        --      end
          end
        end
    
        -- DebugCross(G_cache[index].pos)
    end

      -- for x,yAxis in pairs(vertecies) do 
  --     for y,zAxis in pairs(yAxis) do 
  --         for z,v in pairs(zAxis) do
  --             count = count + 1
  --          --   DebugCross(Vec(x,y,z))
  --             AutoTooltip(#v,Vec(x,y,z),false,2)
  --             if count == 3000 then 
  --                 break
  --             end
  --         end
  --     end
  -- end
    --if InputPressed("k") then
       -- 
      --  DebugPrint("wh")
       -- AutoInspectWatch(path," ",1," ")
   -- end

 -- 
 -- 
 -- 
 -- 
 -- 
 -- 
    
--  for j = 1, #cacheSort do 
--      local indexi = j
--      for i = 1, #cacheSort[indexi] do 
--          local index = cacheSort[indexi][i]
--          local dist = AutoVecDist(p, G_cache[index].pos)
--          
--          if dist < cloesestDist then
--              cloesestDist = dist
--              cloesestPoint = G_cache[index].pos
--          end
--      end
--  end

   --for j = 1, #cacheSort do 
   --    local indexi = j
   --    for i = 1, #cacheSort[indexi] do 
   --        local index = cacheSort[indexi][i]
   --        if pointInBox(p,G_cache[index].min,G_cache[index].max) then
   --            cloesestPoint = G_cache[index].pos
   --        end
   --    end
   --end
end




function determinNeighboursOld()    -- Super slow super bad super brute force
    local counter = 0
    for index = #cacheSort, 1, -1 do
        local boxesInThisDepth = cacheSort[index]

        if #boxesInThisDepth == 0 then
            -- Skip the loop if there are no boxes in this depth
        else
            local directions = {}
            local currentBox = boxesInThisDepth[1]
            local minBox = G_cache[currentBox].min
            local maxBox = G_cache[currentBox].max

            directions[1] = {0, maxBox[2] - minBox[2]}
            directions[2] = {0, minBox[2] - maxBox[2]}
            directions[3] = {minBox[1] - maxBox[1], 0}
            directions[4] = {maxBox[1] - minBox[1], 0}
            directions[5] = {0, 0, maxBox[3] - minBox[3]}
            directions[6] = {0, 0, minBox[3] - maxBox[3]}

            for allBoxesInThisDepth = 1, #boxesInThisDepth do
                currentBox = boxesInThisDepth[allBoxesInThisDepth]
                local posCurrentBox = G_cache[currentBox].pos
                local neighborCount = 0  -- Variable to count neighbors

                for dirI = 1, #directions do
                    local dir = directions[dirI]
                    local point = {posCurrentBox[1] + dir[1], posCurrentBox[2] + dir[2], posCurrentBox[3] + (dir[3] or 0)}

                    for j = 1, index do
                        for i = 1, #cacheSort[j] do
                            local boxWeFound = cacheSort[j][i]
                            counter = counter + 1
                            if pointInBox(point, G_cache[boxWeFound].min, G_cache[boxWeFound].max) then
                                G_cache[currentBox].nearby[#G_cache[currentBox].nearby + 1] = boxWeFound
                                G_cache[boxWeFound].nearby[#G_cache[boxWeFound].nearby + 1] = currentBox
                                neighborCount = neighborCount + 1
                                if neighborCount == 6 then
                                    break  -- Stop when 6 neighbors are found
                                end
                            end
                        end

                        if neighborCount == 6 then
                            break  -- Stop when 6 neighbors are found
                        end
                    end

                    if neighborCount == 6 then
                        break  -- Stop when 6 neighbors are found
                    end
                end
            end
        end
    end
    DebugPrint(counter)
end

function calculateFaceCorners(min, max)
    local corners = {}
    -- Corner 1 (min values)
    corners[1] = {min[1], min[2], min[3]}
    -- Corner 2 (max x, min y, min z)
    corners[2] = {max[1], min[2], min[3]}
    -- Corner 3 (max values)
    corners[3] = {max[1], max[2], max[3]}
    -- Corner 4 (min x, max y, min z)
    corners[4] = {min[1], max[2], min[3]}
    return corners
end