--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

--[[
#include ./Birds/Automatic.lua
#include ./registry.lua

]]--

function init()

    Spawn("MOD/boxes.xml",Transform())

    list = {}
    --list[#list+1] = FindBody("128",true)
    list[#list+1] = FindBody("64",true)
    list[#list+1] = FindBody("32",true)
    list[#list+1] = FindBody("16",true)
    list[#list+1] = FindBody("8",true)

    local num = 128

    checkShape = {}
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

    globalt = Transform()



    scanAll(true)
end

function scanAll(debugMode)
    if not debugMode then debugMode = false end
    local min,max = GetBodyBounds(GetWorldBody())
    local minX,maxX = min[1],max[1]
    local minY,maxY = min[2],max[2]
    local minZ,maxZ = min[3],max[3]
    local count = 0

    cacheAll = {}
    local octtreeSize = 16

    local xi,yi,zi = 0,0,0
    DebugLine(GetBodyTransform(checkShape[1].body).pos)
    for x=minX,maxX,octtreeSize do
        for y=minY,maxY,octtreeSize do 
            for z=minZ,maxZ,octtreeSize do
                if count == 1 then 
                    --break
                end

                count = count + 1
                local depth = 1
                local id = count+x+y+z

                globalt.pos = Vec(x,y,z)

                local cache = {}
                cache = recursiveSearch(cache,globalt,depth,globalt,id)
                for xL,yAxis in pairs(cache) do 
                    for yL,zAxis in pairs(yAxis) do 
                        for zL in pairs(zAxis) do
                            --G as in global
                            local gX = xL + xi
                            local gY = yL + yi
                            local gZ = zL + zi

                            if not cacheAll[gX]         then cacheAll[gX] = {}         end
                            if not cacheAll[gX][gY]     then cacheAll[gX][gY] = {}     end
                            if not cacheAll[gX][gY][gZ] then cacheAll[gX][gY][gZ] = {} end
                            cacheAll[gX][gY][gZ] = {}
                            cacheAll[gX][gY][gZ].value = cache[xL][yL][zL].value
                            cacheAll[gX][gY][gZ].min   = VecCopy(cache[xL][yL][zL].min)
                            cacheAll[gX][gY][gZ].max   = VecCopy(cache[xL][yL][zL].max)
                            cacheAll[gX][gY][gZ].pos   = cache[xL][yL][zL].pos
                            cacheAll[gX][gY][gZ].id    = cache[xL][yL][zL].id
                        end 
                    end 
                end
                zi = zi + octtreeSize
            end
            yi = yi + octtreeSize
        end
        xi = xi + octtreeSize
    end

    ClearKey("savegame.mod.birb")
   if debugMode then
       local str = serialize(cacheAll)
       SetString("savegame.mod.birb",str)
   end
end

function draw(dt)

    AutoDrawAABB(GetBodyBounds(GetWorldBody()))
    --scanAll()
   -- local cache = {}
   -- local depth = 1 
   -- local id = 1
   --recursiveSearch(cache,globalt,depth,globalt,id)
  local ids = {}
  ids[#ids+1] = 0
 count = 0
for x,yAxis in pairs(cacheAll) do 
    for y,zAxis in pairs(yAxis) do 
        for z in pairs(zAxis) do
            if cacheAll[x][y][z].value == -1 then
                --ids[#ids+1] = cacheAll[x][y][z].id
                 --AutoTooltip(cacheAll[x][y][z].value,cacheAll[x][y][z].pos,false,2,1)
                --DebugLine(cacheAll[gX][gY][gZ].min,cacheAll[gX][gY][gZ].max,0,0,0,1)
                AutoDrawAABB(cacheAll[x][y][z].min,cacheAll[x][y][z].max,0,0,0,1)
            end
        end 
    end 
end


   -- local depth = 1
   -- count = 1
   -- recursiveSearch(globalt,depth)
   -- print("start")
end


function recursiveSearch(cache,t,depth,mainBodyT,count)
    SetBodyTransform(checkShape[depth].body,t)
    local cost = math.pow(2,depth)
    for i=1, #checkShape[depth].shapes do
        QueryRequire("physical visible")

        local id = depth+checkShape[depth].shapes[i]+count
        local min,max = GetShapeBounds(checkShape[depth].shapes[i])
        local shapes = QueryAabbShapes(min,max)
        local tShape = GetShapeWorldTransform(checkShape[depth].shapes[i])
       -- AutoDrawAABB(min,max,0,0,0,0.5)
        if #shapes == 0 then
           calculateValue(min,max,cache,cost,mainBodyT,tShape,id)
            --AutoDrawAABB(min,max,0,0,0,1)
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
                --AutoDrawAABB(min,max,0,0,0,1)
                calculateValue(min,max,cache,cost,mainBodyT,tShape,id)
            elseif depth == 4 then
                --AutoDrawAABB(min,max,0,0,0,1)
                calculateValue(min,max,cache,-1,mainBodyT,tShape,id)
            end
        end
    end
    return cache
end

function calculateValue(min,max,cache,value,mainBodyT,tShape,id)
    local minX,maxX = min[1],max[1]
    local minY,maxY = min[2],max[2]
    local minZ,maxZ = min[3],max[3]

    local dx = math.floor(maxX - minX)
    local dy = math.floor(maxY - minY)
    local dz = math.floor(maxZ - minZ)

    local xi,yi,zi = 1,1,1 
    local x,y,z = 1,1,1
    local point = TransformToParentPoint(tShape,Vec(xi,yi,zi))
    local localPoint = AutoVecRound(TransformToLocalPoint(mainBodyT,point))
    local x,y,z = localPoint[1],localPoint[2],localPoint[3]
    if not cache[x] then cache[x] = {}             end
    if not cache[x][y] then cache[x][y] = {}       end
    if not cache[x][y][z] then cache[x][y][z] = {} end
    cache[x][y][z] = {}
    cache[x][y][z].value = value
    cache[x][y][z].min = AutoVecRound(min)
    cache[x][y][z].max = AutoVecRound(max)
    cache[x][y][z].pos = AutoVecRound(point)
    cache[x][y][z].id = math.floor(id)

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