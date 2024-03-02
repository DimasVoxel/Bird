--[[
#include /script/registry.lua
#include /script/Automatic.lua
]]

function init()
    id = 0
    path = {}
    ringSprite = LoadSprite("gfx/ring.png")

    startpos = Vec()
    endpos = Vec()
end

function tick()
   -- if InputPressed("e") then 
   --     for i=1,100 do 
   --         --requestNewPath()
   --         --SetString("level.birb.waiting."..id..".status","waiting")
   --     end
   -- end

    local t = GetPlayerCameraTransform()
    local fwd = TransformToParentVec(t,Vec(0,0,-1))

    local hit,dist,normal = QueryRaycast(t.pos,fwd,300)
    local hitpoint = VecAdd(VecAdd(t.pos,VecScale(fwd,dist)),normal)

    local boolShift = InputDown("shift")

    if boolShift then
        if InputPressed("lmb")  then
            startPos = hitpoint
        end

        if InputPressed("rmb") then
            endPos = hitpoint
        end

        if InputPressed("e") then 
            requestNewSpecificPath(startPos,endPos)
        end
    end 
    DebugLine(startPos,endPos,1,1,1,1)

    for i=1, #path do 
        if i ~= #path then
            --DebugLine(curve[i],GetPlayerPos())
            DebugLine(path[i].pos,path[i+1].pos,1,1,0,1)
            DrawSprite(ringSprite,Transform(path[i].pos,QuatLookAt(path[i].pos,path[i+1].pos)),path[i].radius,path[i].radius,1,1,1,1)
        end
    end
end

function requestNewSpecificPath(strpos,endpos)

    local id = generateNewId()
    local listener = "pathRecieve"..id

    RegisterListenerTo(listener,"pathRecieve")

    local data = {}
    data.id = id

    data.startPos = strpos
    data.endPos = endpos

    local dataString = serialize(data)
    TriggerEvent("requestPath",dataString)
end

function requestNewPath()
    local min,max = GetBodyBounds(GetWorldBody())

    local id = generateNewId()
    local listener = "pathRecieve"..id

    RegisterListenerTo(listener,"pathRecieve")

    local data = {}
    data.id = id

    data.startPos = Vec(math.random(min[1],max[1]),math.random(min[2],max[2]),math.random(min[3],max[3]))
    data.endPos = Vec(math.random(min[1],max[1]),math.random(min[2],max[2]),math.random(min[3],max[3]))

    local dataString = serialize(data)
    TriggerEvent("requestPath",dataString)
end

function generateNewId()
    local id = GetInt("level.birdPathFind",0)+1
    SetInt("level.birdPathFind",id)
    return id 
end

function pathRecieve(dataString)
    local data = unserialize(dataString)
    if data.status == "error" then
        DebugPrint("The provided path was nil. Requesting another path")
        requestNewPath()
        return
    end
    local listener = "pathRecieve"..data.id
    UnregisterListener(listener,"pathUpdate")
    pathPostProcessor(data)
   
end

function pathPostProcessor(data)

    local pathData = data.path
    local knots = {}
--  print(serialize(data))
--  print(#data)


    knots[#knots+1] = data.startPos
    knots[#knots+1] = pathData[1].pos
    for i=1,#pathData do
        if i+1 ~= #pathData and #pathData ~= i then  
            knots[#knots+1] = VecLerp(pathData[i].pos,pathData[i+1].pos,0.5)
        else 
            break
        end
    end
    knots[#knots+1] = pathData[#pathData].pos
    knots[#knots+1] = data.endPos
--
--  local knots2 = {}
--  knots2[#knots+1] = knots[1]
--  for i=1,#knots do
--      if i+1 ~= #knots then  
--          knots2[#knots2+1] = VecLerp(knots[i],knots[i+1],0.5)
--      else 
--          break
--      end
--  end

  -- knots = {}
  -- for i=1,#data do 
  --     knots[#knots+1] = data[i].pos
  -- end
    if #knots > 3 then
        path = buildCardinalSpline(knots,10,pathData)
    else 
        path = knots
    end
end

function buildCardinalSpline(knots,precision,data)
    precision = precision or 30
    local curve = {}

    --Linear spline to cardinal spline https://youtu.be/jvPPXbo87ds?t=2656

    local magicNumber = 4.1
    for i=1, #knots do
        if i ~= #knots-2 then 
            -- # Hermite to bezier conversion https://youtu.be/jvPPXbo87ds?t=2528
            local velocity = VecSub(knots[i+2],knots[i])
            local controllPoint1 = VecScale(velocity,1/magicNumber)
            local velocityKnos2 = VecSub(knots[i+3],knots[i+1])
            local controllPoint1Knot2 = VecScale(velocityKnos2,1/magicNumber)
            local controllPoint2 = VecAdd(knots[i+2],VecScale(controllPoint1Knot2,-1))
            for j=1, precision do 
               -- DebugLine(controllPoint1,GetPlayerPos())
                curve[#curve+1] = {} 
                curve[#curve].pos = bezierFast({knots[i+1],VecAdd(knots[i+1],controllPoint1),controllPoint2,knots[i+2]},j/precision)
                curve[#curve].radius = AutoLerp(data[i].pos[2]-data[i].max[2],data[i+1].pos[2]-data[i+1].max[2],j/precision)
            end
        else 
            break
        end
    end

    return curve
end

function bezierFast(knots, t) -- By Thomasims
    local p1, p2, p3, p4 = knots[1],knots[2],knots[3],knots[4]
	local omt = 1 - t
	local t2, omt2 = t ^ 2, omt ^ 2

	local p = VecAdd(VecAdd(VecAdd(VecScale(p1, omt ^ 3), VecScale(p2, 3 * t * omt2)), VecScale(p3, 3 * t2 * omt)),
		VecScale(p4, t ^ 3))
	return p
end