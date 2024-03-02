--[[
#include ../script/Automatic.lua
#include ../script/registry.lua
]]

function init()
    birdInit()
    animationInit()
    stateInit()
    behaviourTableInit()
    initPathFindAPI()
end

function initPathFindAPI()

    pathData = {}
    ringSprite = LoadSprite("gfx/ring.png")
    flightData = {}
    flightData.status = "idle"
    flightData.speedBoost = 0
    flightData.timeGliding = 0
end

function behaviourTableInit()
    local function totalPercent(table)
        total = 0
        for i = 1, #table do
          total = total + table[i][2]
        end
        return total
    end

    behaviourTable = {
        onHardGround = {
            eventTable = {
                { "idle", 60 },
                { "peck", 12 },
                { "walk", 25 },
                { "fly", 5 },
            },
            totalPercent = 0
        },

        onDirtGround = {
            eventTable = {
            { "idle", 60 },
            { "peck", 15 },
            { "walk", 20 },
            { "fly", 2 },
            },
            totalPercent = 0
        }
    }

    for node,table in pairs(behaviourTable) do 
        behaviourTable[node].totalPercent = totalPercent(table.eventTable)
    end
end

function behaviourStack()
    stack = {}
    stack.queue = {}
end

function stackEntry(time,behaviour)
    local index = #stack.queue+1

    time = time or 1
    behaviour = behaviour or "idle"

    stack.queue[index].timer = time
    stack.queue[index].behaviour = behaviour
end

function stateInit()
    state = {}
    state.randomEvent = "idle"
    state.randomEventTimer = 1
    state.randomEventDuration = 0
    state.eventInitialized = false
end

function animationInit()
    animation = {}
    animation.flapSpeed = 0
    animation.flapping = false
    animation.flappingAnimation = 0
    animation.Glide = Quat()

    animation.headPecking = false
    animation.headTimer = 0
end

function birdInit()
    bird = {}
    bird.body = FindBody('bird', false)
    bird.transform = GetBodyTransform(bird.body)
    bird.fwd = TransformToParentVec(bird.transform, Vec(0, 0, -1))
    bird.allShapes = FindShapes("", false)
    bird.allBodies = FindBodies("")
    bird.allowedVelocity = 0
    bird.vel = GetBodyVelocity(bird.body)
    bird.alive = true
    bird.canFly = true

    bird.supposedRotation = Quat()
    bird.mass = GetBodyMass(bird.body)
    bird.onGround = false

    bird.head = {}
    bird.head.body = FindBody("head")
    bird.head.transform = GetBodyTransform(bird.head.body)
    bird.head.localTransform = TransformToLocalTransform(bird.transform,bird.head.transform)

    bird.wings = {}
    local wings = FindBodies("wing")
    for i = 1, #wings do
        local body = wings[i]
        bird.wings[#bird.wings + 1] = {}
        bird.wings[#bird.wings].body = body
        if HasTag(body, "left") then
            bird.wings[#bird.wings].side = "left"
        else
            bird.wings[#bird.wings].side = "right"
        end
        local t = GetBodyTransform(body)
        bird.wings[#bird.wings].transform = t
        bird.wings[#bird.wings].localTransform = TransformToLocalTransform(bird.transform, t)
        bird.wings[#bird.wings].currentWingRot = TransformToParentTransform(bird.transform, Transform()).rot
    end

    for i = 1, #bird.allShapes do
        local shape = bird.allShapes[i]
        SetShapeCollisionFilter(shape, 250, 5)
    end

    -- This piece crap is to check if the spawn process stopped and to set colission filter again
    initialValues = {
        x = 0,
        y = 0,
        z = 0
      }

    local x,y,z = GetQuatEuler(TransformToLocalTransform(bird.transform,bird.wings[1].transform).rot)
    initialValues.x = x
    initialValues.y = y
    initialValues.z = z
    randomAssCounter = 0
end



function birdUpdate(dt)

    if bird.alive == false then return end 
    if InputDown("o") then DebugLine(bird.transform.pos,GetPlayerPos()) end
    for i=1,#bird.wings do 
        if IsBodyBroken(bird.wings[i].body) then bird.canFly = false end 
    end

    bird.transform = GetBodyTransform(bird.body)
    bird.fwd = TransformToParentVec(bird.transform, Vec(0, 0, -1))
    bird.up = TransformToParentVec(bird.transform, Vec(0, 1, 0))
    bird.wingAxis = TransformToParentTransform(bird.transform, bird.wingAxisLocalTransform)
    local com = GetBodyCenterOfMass(bird.body)
    bird.com = TransformToParentPoint(bird.transform, com)
    bird.vel = GetBodyVelocity(bird.body)

    bird.status = "roam"

    bird.head.transform = GetBodyTransform(bird.head.body)

    QueryRequire("physical visible")
    for i=1,#bird.allBodies do 
        QueryRejectBody(bird.allBodies[i])
    end

    local hit,dist,normal,shape = QueryRaycast(bird.transform.pos,Vec(0,-1,0),6,0,false)
    if dist < 0.3 or IsPointInWater(VecAdd(bird.com,Vec(0,-0.5,0))) then 
        bird.onGround = true
        bird.distFromGround = dist
    else 
        bird.onGround = false 
        bird.distFromGround = dist
    end

    if IsBodyBroken(bird.body) or IsBodyBroken(bird.head.body) then 
        bird.alive = false
        local xml = '<joint size="0.3"/>'
        for i = 1, #bird.wings do
            local wing = bird.wings[i]
            local t = GetBodyTransform(wing.body)
            bird.wings[i].transform = t
    
            local hingePoint = TransformToParentTransform(bird.transform, wing.localTransform)
            Spawn(xml,hingePoint,false,true)
            xml = '<joint pos="0.0 0.0 0.0" rot="0.0 90.0 0.0" type="hinge" size="0.3"/>'
            local localTransform = TransformToParentTransform(bird.transform,bird.head.localTransform)
            Spawn(xml,localTransform,false,true)
        end
    end 


    randomEvent(dt)
    handleBirdHead()
    birdMovement()
    if bird.canFly == true then
        handleWings() -- WingAnimation
        flight(dt)
    end


    -- This shit is only here in case 
    local x,y,z = GetQuatEuler(TransformToLocalTransform(bird.transform,bird.wings[1].transform).rot)

    if checkDeviation(x, y, z) then 
        randomAssCounter = randomAssCounter + 1 
        if randomAssCounter > 40 then 
            for i = 1, #bird.allShapes do
                local shape = bird.allShapes[i]
                SetShapeCollisionFilter(shape, 250, 5)
            end
        end 
    else 
        randomAssCounter = math.max(randomAssCounter - 2,0)
    end
end

function checkDeviation(x, y, z)
    -- Calculate the sum of absolute differences
    local sumOfDifferences = math.abs(x - initialValues.x) + math.abs(y - initialValues.y) + math.abs(z - initialValues.z)
  
    -- Check if the sum of differences is at least 20
    return sumOfDifferences >= 15
  end

function returnClosestSegment()

    local data = pathData[1].path
    local closestDist = 20000
    local closestSegmentNr = 0

    -- Step 1: Check every 10th value
    for i = 1, #data, 10 do
        local dist = AutoVecDist(data[i].pos, bird.transform.pos)

        if dist < closestDist then
            closestDist = dist
            closestSegmentNr = i
        end
    end

    -- Step 2: Perform a detailed search in the identified segment
    local startSearchIndex = math.max(1, closestSegmentNr - 9)
    local endSearchIndex = math.min(#data, closestSegmentNr + 9)

    for i = startSearchIndex, endSearchIndex do
        local dist = AutoVecDist(data[i].pos, bird.transform.pos)

        if dist < closestDist then
            closestDist = dist
            closestSegmentNr = i
        end
    end

    -- Now closestSegmentNr contains the index of the closest segment
    return closestSegmentNr
end


function debug()
   --AutoInspectWatch(pathFind,"path",1," ",false)
    if state.randomEvent == "foundFlightPath" then
        local closestSegment = returnClosestSegment()
        local data = pathData[1].path

        local dirToBirb, dirToNextSegment 
        if closestSegment ~= #data then 
            dirToBirb = VecNormalize(VecSub(data[closestSegment].pos,bird.transform.pos))
            dirToNextSegment = VecNormalize(VecSub(data[closestSegment].pos,data[closestSegment].pos))
        end 

        if VecDot(dirToNextSegment,dirToBirb) >= 0 and closestSegment ~= 1 then 
            closestSegment = closestSegment - 1
        end



       DebugLine(data[1].pos,pathData[1].startPos)
        for i=1,#data do
            if i ~= #data then
                DebugLine(data[i].pos,data[i+1].pos,1,1,0,1)
                DebugCross(data[i].pos)
              --  DrawSprite(ringSprite,Transform(data[i].pos,QuatLookAt(data[i].pos,data[i+1].pos)),data[i].radius,data[i].radius,1,1,1,1)
            end
        end
        DebugLine(data[#data].pos,pathData[1].endPos,1,1,0,1)
    end
end

function draw(dt)
    if InputDown("k") then
        debug()
    end

end



function flight(dt)



   --AutoInspectWatch(pathFind,"path",1," ",false)
    if state.randomEvent == "foundFlightPath" then

        if pathData[1].path == nil then 
            table.remove(pathData,1)
            return
        end

        local closestSegment = returnClosestSegment()
        local data = pathData[1].path

        local dirToBirb, dirToNextSegment 
        if closestSegment+1 < #data then 
            closestSegment = closestSegment+1
            dirToBirb = VecNormalize(VecSub(data[closestSegment+1].pos,bird.transform.pos))
            dirToNextSegment = VecNormalize(VecSub(data[closestSegment].pos,data[closestSegment].pos))
        end 

        if VecDot(dirToNextSegment,dirToBirb) >= 0 and closestSegment ~= 1 then 
            closestSegment = closestSegment - 1
        end

    --DebugLine(data[closestSegment].pos,bird.transform.pos,1,0,0,1)
        if closestSegment+10 < #data then
            local dif = #data - closestSegment - 10 
            local dist = AutoVecDist(data[closestSegment+10].pos,bird.transform.pos)
            local lookAheadDir = VecNormalize(VecSub(data[closestSegment+10].pos,bird.transform.pos))
        --    DebugLine(VecAdd(bird.transform.pos,lookAheadDir),bird.transform.pos)

            --DebugPrint(data[closestSegment].radius)

            local difStart = AutoClamp(closestSegment/60,0.5,1)

            local force = (math.abs(data[closestSegment].radius)*math.min(dif/60,1))*difStart

            local yOffset = bird.com[2] - data[closestSegment+3].pos[2]
            local hover = 0.17

            if yOffset < hover then
                local desiredForce = AutoClamp((hover - yOffset) * 10,-1.5,3)
                ConstrainVelocity(bird.body, 0, bird.com, Vec(0,1,0), desiredForce,-20,40)
            end

            ConstrainVelocity(bird.body,0,bird.com,bird.fwd,1)

            local localVel = TransformToLocalVec(bird.transform, bird.vel)
            local antiSideways = Vec(localVel[1] * -1, 0, 0)
            local newVel = TransformToParentVec(bird.transform, antiSideways)
            local speed = VecLength(newVel)

           -- DebugLine(bird.transform.pos,VecAdd(bird.transform.pos,newVel))

            if speed > 0.5 and bird.onGround == false then
                ConstrainVelocity(bird.body, 0, bird.com, newVel, speed, math.min( speed, 10) * -1, math.min( speed, 10))
            end

            local dot = VecDot(bird.fwd,Vec(0,1,0))
            local dotFwd = AutoClamp(math.abs(dot),0.5,1)

            if dot <= 0.3 and dot >= -0.3 then 
                flightData.timeGliding = flightData.timeGliding + dt/2
            else 
                flightData.timeGliding = flightData.timeGliding - dt*2
            end
            flightData.timeGliding = AutoClamp(flightData.timeGliding,1,2)

            

            local quat = QuatLookAt(bird.transform.pos,data[closestSegment+10].pos)
            
            local total = 60
            if dif < total then
            --    DebugPrint(dif) 
                local x,y,z = GetQuatEuler(quat)
                local newQuat = QuatEuler(0,y,0)

                flightData.timeGliding = flightData.timeGliding - dt*3
             --   DebugPrint(dif/total)

                ConstrainOrientation(bird.body,0,bird.transform.rot,newQuat,10,15)
            else 
                
                ConstrainOrientation(bird.body,0,bird.transform.rot,quat,10,20)
            end
            ConstrainVelocity(bird.body,0,bird.com,bird.fwd,10*(1-dotFwd+0.1)*(flightData.timeGliding)*difStart)
        else 
            eventReset()
            table.remove(pathData,1)
        end

    --  DebugLine(path[#path].pos,pathData[1].endpos,1,1,0,1)
    end
end

function roundToNearestOne(number)
    if number > 0 then
        return 1
    else
        return -1
    end
end


function handleBirdHead()
    local localTransform = TransformToParentTransform(bird.transform,bird.head.localTransform)
    ConstrainPosition(bird.head.body, bird.body, bird.head.transform.pos, localTransform.pos)
    if state.randomEvent == "peck" then -- Head Animation 
        local initialQuat = localTransform.rot
        local sideways = TransformToParentVec(bird.transform,Vec(-1,0,0))
        local rotateQuat = QuatAxisAngle(sideways,80)
        ConstrainOrientation(bird.head.body,bird.body,bird.head.transform.rot,QuatRotateQuat(rotateQuat,initialQuat),30,10)
    else
        ConstrainOrientation(bird.head.body,bird.body,bird.head.transform.rot,localTransform.rot,30,10)
    end
end

function eventReset()
    state.randomEvent = "idle"
    state.eventInitialized = false
end

function randomEvent(dt)
    --AutoInspectWatch(state,"state",1," ",false)
    if state.randomEventTimer <= 0 then
        state.randomEvent = getrandom(behaviourTable.onHardGround.eventTable,behaviourTable.onHardGround.totalPercent)
        state.randomEventTimer = math.random(1,3) - math.random() 

        state.eventInitialized = false

    elseif state.randomEvent == "idle" then 
        state.randomEventTimer = state.randomEventTimer - dt
    end

    if state.randomEvent == "peck" then
        if state.eventInitialized == false then 
            state.eventInitialized = true
            state.randomEventDuration = math.min(math.random(),0.2) + 0.05
        end 

        state.randomEventDuration = state.randomEventDuration - dt
        if state.randomEventDuration <= 0 then 
            eventReset()
        end
    elseif state.randomEvent == "walk" then
        ApplyBodyImpulse(bird.body,bird.com,VecScale(VecAdd(bird.up,bird.fwd),bird.mass*4))
        if state.randomEventDuration <= 0 then 
            eventReset()
        end
    elseif state.randomEvent == "fly" then
        if bird.onGround and flightData.status == "idle" and bird.canFly then
            local min,max = GetBodyBounds(GetWorldBody())
            min = VecAdd(min,Vec(5,0,5))
            max = VecAdd(max,Vec(-5,0,-5))
            local startPos = VecAdd(bird.transform.pos,Vec(0,1.5,0))
            local endPos
            for i=1,10 do 
                local randomPos = Vec(math.random(min[1],max[1]),math.random(min[2],max[2]),math.random(min[3],max[3]))
                QueryRequire("physical large visible")
                local hit,dist = QueryRaycast(randomPos,Vec(0,-1,0),200,0,false)
                endPos = VecAdd(randomPos,VecScale(Vec(0,-1,0),dist-1))
                if hit and IsPointInWater(endPos) == false then 
                    flightData.status = "waiting"
                    requestFlyPath(startPos,endPos)
                    break
                end
            end
            eventReset()
        else 
            eventReset()
        end
    end
end



function getrandom(table,total) -- Feat Thomasims 
    local roll = math.random()
    for i = 1, #table do
      local weightedchance = table[i][2] / total
      if weightedchance > roll then
        return table[i][1]
      end
      roll = roll - weightedchance
    end
end

function handleWings()
    for i = 1, #bird.wings do
        local wing = bird.wings[i]
        local t = GetBodyTransform(wing.body)
        bird.wings[i].transform = t

        local hingePoint = TransformToParentTransform(bird.transform, wing.localTransform)
        ConstrainPosition(wing.body, bird.body, t.pos, hingePoint.pos)

        bird.wings[i].currentWingRot = TransformToParentTransform(bird.transform, Transform()).rot
        if state.randomEvent == "foundFlightPath" and bird.onGround == false then
            wingAnimation()
        else 
            ConstrainOrientation(wing.body, 0, wing.transform.rot, wing.currentWingRot, 10)
        end
    end
end

function birdMovement()
    --ConstrainOrientation(bird.body,0,bird.transform.rot,Quat(),10,10)

    if bird.onGround == true then
        local cross = VecCross(Vec(0, -1, 0), bird.up)
        ConstrainAngularVelocity(bird.body,0,cross,1)
    

        -- Basic anti wall avoidance behavior
        QueryRequire("physical visible")
        for i=1,#bird.allBodies do 
            QueryRejectBody(bird.allBodies[i])
        end
        local hit,_,normal = QueryRaycast(bird.head.transform.pos,bird.fwd,2,0.2,false)
        if hit then 
            local cross = VecCross(VecNormalize(Vec(normal[1],0,normal[3])), bird.fwd)
            ConstrainAngularVelocity(bird.body,0,cross,-0.5)
        end
    end 
  --  local playerFwd = TransformToParentVec(GetPlayerTransform(), Vec(0, 0, -1))
  --  local cross = VecCross(playerFwd, bird.up)
  --  local dot = 0.5 - VecDot(bird.fwd, playerFwd)
  --  print(dot)
  --  DebugLine(bird.transform.pos, VecAdd(bird.transform.pos, cross))
  --  ConstrainAngularVelocity(bird.body, 0, cross, dot, -10, 10)

   -- DebugLine(bird.transform.pos,VecAdd(bird.transform.pos,bird.fwd))
end

function wingAnimation()

    local dot = 1+VecDot(bird.fwd,Vec(0,1,0))*0.5
    local wingSpeed = 10*dot

    for i = 1, #bird.wings do
        local wing = bird.wings[i]
        local flip = -1
        if wing.side == "right" then
            flip = 1
        end

        local sineInput = GetTime() * wingSpeed
        local align = math.sin(sineInput)*2*flip
        local yaw = math.sin(sineInput + 1) * 10 * -flip 
        local flap = (math.sin(sineInput)+math.sin(sineInput*-1.8)/5) * 50 * flip 

        local flapOffset = 110 * flip
        local offsetYaw = -4 * flip
        local offsetAlign = 90

        rot = TransformToParentQuat(bird.transform, QuatEuler(align+offsetAlign ,yaw + offsetYaw,  flap+flapOffset))
        --SetBodyTransform(wing.body,Transform(TransformToParentTransform(wing.transform,wing.localTransform).pos,rot))
        --SetBodyAngularVelocity(wing.body,Vec())
        ConstrainOrientation(wing.body, 0, wing.transform.rot, rot, 10*dot)
    end
end

function TransformToParentQuat(parentT, quat)
    local childT = Transform(Vec(), quat)
    local t = TransformToParentTransform(parentT, childT)
    return t.rot
end


function update(dt)
    birdUpdate(dt)
end



-------------# Path Finding API #--------------

function requestFlyPath(strpos,endpos)

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

function generateNewId()
    local id = GetInt("level.birdPathFind",0)+1
    SetInt("level.birdPathFind",id)
    return id 
end

function pathRecieve(dataString)
    
    local data = unserialize(dataString)

    if data.status == "error" then
        print("The provided path was nil. Requesting another path")
        requestNewPath()
        return
    end
    local listener = "pathRecieve"..data.id
    UnregisterListener(listener,"pathUpdate")
    pathPostProcessor(data)
   
end

function pathPostProcessor(data)

    local dataPath = data.path
    local knots = {}
--  print(serialize(data))
--  print(#data)

    knots[#knots+1] = data.startPos
    knots[#knots+1] = dataPath[1].pos
    for i=1,#dataPath do
        if i+1 ~= #dataPath and #dataPath ~= i then  
            knots[#knots+1] = VecLerp(dataPath[i].pos,dataPath[i+1].pos,0.5)
        else 
            break
        end
    end
    knots[#knots+1] = dataPath[#dataPath].pos
    knots[#knots+1] = data.endPos

    if #knots > 4 then
        pathData[#pathData+1] = {}
        pathData[#pathData].startPos = data.startPos
        pathData[#pathData].endPos = data.endPos
        pathData[#pathData].path = buildCardinalSpline(knots,14,dataPath)

        state.randomEvent = "foundFlightPath"
        flightData.status = "idle"
    else 
        state.randomEvent = "idle"
    end
        --else
   --    pathData[#pathData+1] = knots
   --    state.randomEvent = "foundFlightPath"
   --end
end

function buildCardinalSpline(knots,precision,data)
    precision = precision or 30
    local curve = {}

    --Linear spline to cardinal spline https://youtu.be/jvPPXbo87ds?t=2656

    local magicNumber = 4.1 -- Magic number explained https://youtu.be/jvPPXbo87ds?t=2824
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

