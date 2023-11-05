--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

#include ./Birds/Automatic.lua

function init()

    Spawn("MOD/boxes.xml",Transform())

    list = {}
    list[1] = FindBody("128",true)
    list[2] = FindBody("64",true)
    list[3] = FindBody("32",true)
    list[4] = FindBody("16",true)
    list[5] = FindBody("8",true)

    local num = 128

    checkShape = {}
    for i=1,5 do
        checkShape[i] = {}
        checkShape[i].size = num/i
        checkShape[i].body = list[i]
        checkShape[i].shapes = GetBodyShapes(list[i])
        for j=1, # checkShape[i].shapes do
            SetTag(checkShape[i].shapes[j],"invisible")
            SetTag(checkShape[i].shapes[j],"unbreakable")
        end
    end

    globalt = Transform()
end

function tick(dt)
    if InputDown("t") then
        local tp = GetPlayerCameraTransform()
        local fwd = TransformToParentVec(tp,Vec(0,0,-1))
        globalt = tp
        globalt.pos = VecAdd(tp.pos,VecScale(fwd,50))
    end
    -- for b=1, #checkShape do
    --     SetBodyTransform(checkShape[b].body,t)
    --     for i=1,#checkShape[b].shapes do 
    --         local shape = checkShape[b].shapes[i]
    --         QueryRequire("visible physical")
    --         if #QueryAabbShapes(GetShapeBounds(shape)) ~= 0 then 
    --             DrawShapeOutline(shape,1,0,0,1)
    --             SetTag(shape,"invisible")
    --         else 
    --             RemoveTag(shape,"invisible")
    --         end
    --     end
    -- end



    local depth = 1
    count = 1
    recursiveSearch(globalt,depth)
end

function recursiveSearch(t,depth)
    SetBodyTransform(checkShape[depth].body,t)

    for i=1, #checkShape[depth].shapes do
        QueryRequire("physical visible")
        local shapes = QueryAabbShapes(GetShapeBounds(checkShape[depth].shapes[i]))
        if #shapes == 0 then
            AutoDrawAABB(GetShapeBounds(checkShape[depth].shapes[i]))
        elseif depth ~= #checkShape then 
            local none = true
            for j=1,#shapes do 
                if IsShapeTouching(checkShape[depth].shapes[i],shapes[j]) then
                    recursiveSearch(GetShapeWorldTransform(checkShape[depth].shapes[i]),depth + 1)
                    none = false 
                    break 
                end 
            end
            if none == true then 
                AutoDrawAABB(GetShapeBounds(checkShape[depth].shapes[i]))
            end
        end
    end
end

function pointInBox(point, minPoint, maxPoint)
    for i = 1, 3 do
        if point[i] < minPoint[i] or point[i] > maxPoint[i] then
            return false
        end
    end
    return true
end

function draw(dt)
end


