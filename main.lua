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

    sizes = {}
    for i=1,5 do 
        sizes[i] = {}
        sizes[i].body = list[i]
        sizes[i].shapes = GetBodyShapes(list[i])
        for j=1, # sizes[i].shapes do 
            SetTag(sizes[i].shapes[j],"invisible")
            SetTag(sizes[i].shapes[j],"unbreakable")
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
    local layers = 8
    local tp = GetPlayerCameraTransform()
    local fwd = TransformToParentVec(tp,Vec(0,0,-1))
    local t = GetBodyTransform(sizes[1].body)
    t.pos = VecAdd(tp.pos,VecScale(fwd,20))


    
    for a=1, #sizes do
        SetBodyTransform(sizes[a].body,t)
        for i=1,#sizes[a].shapes do 
            local tshape = GetShapeWorldTransform(sizes[a].shapes[i])
            DebugCross(tshape.pos)
            if #QueryAabbShapes(GetShapeBounds(checker)) ~= 0 then 

            end
        end
    end
end


function draw(dt)
end


