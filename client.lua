--[[
#include /script/registry.lua
#include /script/Automatic.lua
]]

function init()
    id = 0
    path = {}
    ringSprite = LoadSprite("gfx/ring.png")
end

function tick()
    if InputPressed("e") then 
        --for i=1,1 do 
            local min,max = GetBodyBounds(GetWorldBody())

            local id = generateNewId()
            local listener = "pathRecieve"..id

            RegisterListenerTo(listener,"pathRecieve")

            
            local data = {}
            data.id = id

            local startPos = Vec(math.random(min[1],max[1]),math.random(0,200),math.random(min[3],max[3]))
            local endPos = Vec(math.random(min[1],max[1]),math.random(0,200),math.random(min[3],max[3]))

            local hit,dist = QueryRaycast(startPos,Vec(0,-1,0),300,0,false)
            data.startPos = VecAdd(startPos,VecScale(Vec(0,-1,0),dist-4)) 

            local hit,dist = QueryRaycast(endPos,Vec(0,-1,0),300,0,false)
            data.endPos =  VecAdd(endPos,VecScale(Vec(0,-1,0),dist-4)) 

            local dataString = serialize(data)
            TriggerEvent("requestPath",dataString)

            --SetString("level.birb.waiting."..id..".status","waiting")
    --    end
    end

    for i=1, #path do 
        if i ~= #path then
            --DebugLine(curve[i],GetPlayerPos())
            DebugLine(path[i].pos,path[i+1].pos,1,1,0,1)
            DrawSprite(ringSprite,Transform(path[i].pos,QuatLookAt(path[i].pos,path[i+1].pos)),path[i].radius,path[i].radius,1,1,1,1)
        end
    end
end

function generateNewId()
    local id = GetInt("level.birdPathFind",0)+1
    SetInt("level.birdPathFind",id)
    return id 
end

function pathRecieve(dataString)
    local data = unserialize(dataString)
    --DebugWatch("ID",data.id)
    local listener = "pathRecieve"..data.id
    UnregisterListener(listener,"pathUpdate")
    AutoInspectWatch(data,"data",1," ",0.01)
    pathPostProcessor(data.path)
   
end

function pathPostProcessor(data)

    
    local knots = {}
    knots[#knots+1] = data[1].pos
    for i=1,#data do
        if i+1 ~= #data then  
            knots[#knots+1] = VecLerp(data[i].pos,data[i+1].pos,0.5)
        else 
            break
        end
    end

    path = buildCardinalSpline(knots,10,data)
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
            for j=0, precision do 
               -- DebugLine(controllPoint1,GetPlayerPos())
                curve[#curve+1] = {} 
                curve[#curve].pos = bezierFast({knots[i+1],VecAdd(knots[i+1],controllPoint1),controllPoint2,knots[i+2]},j/precision)
                curve[#curve].radius = AutoLerp(data[i].pos-data[i].max[2],data[i+1].pos-data[i+1].max[2],j/precision)
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