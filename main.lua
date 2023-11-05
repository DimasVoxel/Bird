--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

function init()
    checker = FindShape("check",true)
    checkerBody = GetShapeBody(checker)

    checker128 = FindBody("128",true)
    checker64 = FindBody("64",true)
    checker32 = FindBody("32",true)
    checker16 = FindBody("16",true)
    checker8 = FindBody("8",true)

    list = {}
    list[1] = checker128
    list[2] = checker64
    list[3] = checker32
    list[4] = checker16
    list[5] = checker8

    local num = 128

    checkShape = {}
    for i=1,5 do
        checkShape[i] = {}
        checkShape[i].size = num/i
        checkShape[i].body = list[i]
        checkShape[i].shapes = GetBodyShapes(list[i])
        for j=1, # checkShape[i].shapes do
          --  SetTag(checkShape[i].shapes[j],"invisible")
            SetTag(checkShape[i].shapes[j],"unbreakable")
        end
    end
end

  --  function tick(dt)
  --      local t = GetPlayerCameraTransform()
  --      local pos = t.pos
--
  --      SetBodyTransform(checkerBody,t)
  --      local shapes = QueryAabbShapes(VecAdd(pos,Vec(-20,-20,-20)),VecAdd(pos,Vec(20,20,20)))
  --      for i=1, #shapes do
  --          if IsShapeTouching(checker,shapes[i]) then 
  --              DrawShapeHighlight(shapes[i],1)
  --          end
  --      end
  --  end


function tick(dt)
    local currentPos = Vec(0,0,0)
    local tp = GetPlayerCameraTransform()
    local fwd = TransformToParentVec(tp,Vec(0,0,-1))
    local t = GetBodyTransform(checkShape[1].body)
    t.pos = VecAdd(tp.pos,VecScale(fwd,20))

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

    local search = {}
    search.depth = 1
    TrueDepth = 0
    recursiveSearch(search,t)
    DebugPrint("here".. TrueDepth)
end

function recursiveSearch(search,t)
    TrueDepth = TrueDepth + 1
    SetBodyTransform(checkShape[search.depth],t)
    local tNew = Transform()
    for i=1, #checkShape[search.depth].shapes do
        DebugLine(GetPlayerTransform().pos,GetShapeWorldTransform(checkShape[search.depth].shapes[i]).pos)
        tNew = GetShapeWorldTransform(checkShape[search.depth].shapes[i])
        for j=search.depth,#checkShape[search.depth] do 
            SetBodyTransform(checkShape[j].body,tNew)
        end
    end
    if search.depth ~= #checkShape then 
        DebugPrint(search.depth) 
        search.depth = search.depth + 1
    else
        return
    end 
    recursiveSearch(search,tNew)
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


