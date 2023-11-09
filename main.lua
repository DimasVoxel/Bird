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
                if count == 1 then 
                    --break
                end
                count = count + 1
                globalt= Transform(Vec(x,y,z))
                
                cache = {}
                cache = recursiveSearch(cache,globalt,1,globalt)
                for i=1,#cache do 
                    G_cache[#G_cache+1] = {}
                    G_cache[#G_cache].value = cache[i].value
                    G_cache[#G_cache].min   = VecCopy(cache[i].min)
                    G_cache[#G_cache].max   = VecCopy(cache[i].max)
                    G_cache[#G_cache].pos   = cache[i].pos

                    cacheSort[cache[i].depth][#cacheSort[cache[i].depth]+1] = #G_cache
                end
                zi = zi + octtreeSize
            end
            yi = yi + octtreeSize
        end
        xi = xi + octtreeSize
    end

    ClearKey("savegame.mod.birb")
   if debugMode then
       local str = serialize(G_cache)
       SetString("savegame.mod.birb",str)
   end
end

function determinNeighbours()
    for index=#cacheSort,1, -1 do
        local directions = {}
        directions[1] = {0, G_cache[cacheSort[index][1]].max[2] - G_cache[cacheSort[index][1]].min[2]}
        directions[2] = {0, G_cache[cacheSort[index][1]].min[2] - G_cache[cacheSort[index][1]].max[2]}
        directions[3] = {G_cache[cacheSort[index][1]].min[1] - G_cache[cacheSort[index][1]].max[1], 0}
        directions[4] = {G_cache[cacheSort[index][1]].max[1] - G_cache[cacheSort[index][1]].min[1], 0}
        directions[5] = {0, 0, G_cache[cacheSort[index][1]].max[3] - G_cache[cacheSort[index][1]].min[3]}
        directions[6] = {0, 0, G_cache[cacheSort[index][1]].min[3] - G_cache[cacheSort[index][1]].max[3]}
        for i=1,#cacheSort[index] do
            local indexG = cacheSort[index][i]
            for dirI=1,#directions do
                local point = VecAdd(G_cache[indexG].pos,directions[dirI])
                for cacheNewIndex=(#cacheSort+1) - index,1,-1 do
                    for all=1,#cacheSort[cacheNewIndex] do 
                    --pointInBox(point,G_cache[cacheSort[index]])
                    AutoDrawAABB(G_cache[all].min,G_cache[all].max,0,0,0,1)
                    end
                   
                end
            end

            DebugLine(G_cache[indexG].pos,VecAdd(G_cache[indexG].pos,directions[1]))
            AutoDrawAABB(G_cache[indexG].min,G_cache[indexG].max,0,0,0,1)
        end
        break
    end
end

function draw(dt)
    determinNeighbours()
    AutoDrawAABB(GetBodyBounds(GetWorldBody()))
    --scanAll()
   -- local cache = {}
   -- local depth = 1 
   -- local id = 1
  ----recursiveSearch(cache,globalt,depth,globalt,id),
  --for j=1,#cacheSort do 
  --    local indexi = j
  --    for i=1,#cacheSort[indexi] do 
  --        local index = cacheSort[indexi][i]
  --        --ids[#ids+1] = cacheAll[x][y][z].id
  --        --AutoTooltip(cacheAll[x][y][z].value,cacheAll[x][y][z].pos,false,2,1)
  --        --DebugLine(G_cache[index].min,G_cache[index].max,0,0,0,1)
  --       -- AutoDrawAABB(G_cache[index].min,G_cache[index].max,0,0,0,1)
  --        DebugLine(G_cache[cacheSort[indexi][i]].pos,VecAdd(G_cache[cacheSort[indexi][i]].pos,Vec(0,G_cache[cacheSort[indexi][i]].max[2]-G_cache[cacheSort[indexi][i]].min[2],0)))
  --    end

  --    
  --  --  
  --end

 --  for i=1,#G_cache do 
 --      --ids[#ids+1] = cacheAll[x][y][z].id
 --      --AutoTooltip(cacheAll[x][y][z].value,cacheAll[x][y][z].pos,false,2,1)
 --      --DebugLine(cacheAll[gX][gY][gZ].min,cacheAll[gX][gY][gZ].max,0,0,0,1)
 --   --   AutoDrawAABB(G_cache[i].min,G_cache[i].max,0,0,0,1)
 --      DebugLine(G_cache[i].pos,VecAdd(G_cache[i].pos,Vec(0,G_cache[i].max[2]-G_cache[i].min[2],0)))
 --  end
end

local L

function recursiveSearch(cache,t,depth,mainBodyT,count)
    SetBodyTransform(checkShape[depth].body,t)
    local cost = math.pow(2,depth)
    for i=1, #checkShape[depth].shapes do
        
        QueryRequire("physical visible")
        local min,max = GetShapeBounds(checkShape[depth].shapes[i])
        local shapes = QueryAabbShapes(min,max)
        local tShape = GetShapeWorldTransform(checkShape[depth].shapes[i])
        if #shapes == 0 then
           calculateValue(AutoVecRound(min),AutoVecRound(max),cache,cost,depth)
        else
            local none = true
            for j=1,#shapes do 
                if IsShapeTouching(checkShape[depth].shapes[i],shapes[j]) then
                    if depth ~= #checkShape then
                        cache = recursiveSearch(cache,tShape,depth + 1,mainBodyT,count)
                    end
                    none = false 
                    break 
                end 
            end
            if none == true then 
                calculateValue(AutoVecRound(min),AutoVecRound(max),cache,cost,depth)
            elseif depth == #checkShape then
                calculateValue(AutoVecRound(min),AutoVecRound(max),cache,-1,depth)
            end
        end
    end
    return cache
end

function calculateValue(min,max,cache,value,depth)
    local index = #cache+1
    cache[index] = {}

    cache[index].value = value
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