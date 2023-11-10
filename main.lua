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

function init()
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
                        G_cache[#G_cache].min   = VecCopy(cache[i].min)
                        G_cache[#G_cache].max   = VecCopy(cache[i].max)
                        G_cache[#G_cache].pos   = cache[i].pos
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


   -- determinNeighbours()

    ClearKey("savegame.mod.birb")
    if debugMode then
        local str = serialize(G_cache)
        SetString("savegame.mod.birb",str)
    end
end

function determinNeighbours()
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
end



function draw(dt)
    AutoDrawAABB(GetBodyBounds(GetWorldBody()))
    --scanAll()
local cache = {}
local depth = 1 

recursiveSearch(cache,globalt,depth,globalt)
  -- for j=1,#cacheSort do 
  --     local indexi = j
  --     for i=1,#cacheSort[indexi] do 
  --         local index = cacheSort[indexi][i]
  --         --ids[#ids+1] = cacheAll[x][y][z].id
  --         --AutoTooltip(cacheAll[x][y][z].cost,cacheAll[x][y][z].pos,false,2,1)
  --         --DebugLine(G_cache[index].min,G_cache[index].max,0,0,0,1)
  --         --AutoDrawAABB(G_cache[index].min,G_cache[index].max,0,0,0,1)
  --         --DebugLine(G_cache[cacheSort[indexi][i]].pos,VecAdd(G_cache[cacheSort[indexi][i]].pos,Vec(0,G_cache[cacheSort[indexi][i]].max[2]-G_cache[cacheSort[indexi][i]].min[2],0)))
  --         for i=1,#G_cache[index].nearby do 
  --             local otherPos = G_cache[G_cache[index].nearby[i]].pos
  --             DebugLine(G_cache[index].pos,otherPos,1,1,1,1)
  --         end
  --         DebugCross(G_cache[index].pos)
  --     end
  -- end
end


function recursiveSearch(cache,t,depth,mainBodyT)
    SetBodyTransform(checkShape[depth].body,t)
    local cost = math.pow(2,depth)
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
            --elseif depth == #checkShape then
            --    calculateCost(AutoVecRound(min),AutoVecRound(max),cache,-1,depth)
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