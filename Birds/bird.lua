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
                { "fly", 2000 },
            },
            totalPercent = 0
        },

        onDirtGround = {
            eventTable = {
            { "idle", 60 },
            { "peck", 15 },
            { "walk", 20 },
            { "fly", 0.5 },
            },
            totalPercent = 0
        }
    }

    for node,table in pairs(behaviourTable) do 
        behaviourTable[node].totalPercent = totalPercent(table.eventTable)
    end
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
end



function birdUpdate(dt)
    bird.transform = GetBodyTransform(bird.body)
    bird.fwd = TransformToParentVec(bird.transform, Vec(0, 0, -1))
    bird.up = TransformToParentVec(bird.transform, Vec(0, 1, 0))
    bird.wingAxis = TransformToParentTransform(bird.transform, bird.wingAxisLocalTransform)
    local com = GetBodyCenterOfMass(bird.body)
    bird.com = TransformToParentPoint(bird.transform, com)

    bird.status = "roam"

    bird.head.transform = GetBodyTransform(bird.head.body)

    QueryRequire("physical visible")
    for i=1,#bird.allBodies do 
        QueryRejectBody(bird.allBodies[i])
    end

    local hit,dist,normal,shape = QueryRaycast(bird.transform.pos,Vec(0,-1,0),6,0,false)
    if dist > 0.2 then 
        bird.onGround = false 
        bird.distFromGround = dist
    else 
        bird.onGround = true
        bird.distFromGround = dist
    end


    randomEvent(dt)
    handleBirdHead()
    handleWings() -- WingAnimation
    birdMovement()
    flight()
end

function returnClosestSegment()
    local data = pathData[1].segment
    local closestDist = 20000
    local closestSegmentNr = 0
    
    for i = 1, #data do 
        local pos = data[i].segmentPoint
        local dist = AutoVecDist(pos, bird.transform.pos)
        
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

        local data = pathData[1].segment
        AutoInspectWatch(data," ",1," ")
        local closestSegmentData = data[closestSegment].segmentPathPoints

        local dirToBirb, dirToNextSegment 
        if closestSegment ~= #data then 
            dirToBirb = VecNormalize(VecSub(data[closestSegment].segmentPoint,bird.transform.pos))
            dirToNextSegment = VecNormalize(VecSub(data[closestSegment+1].segmentPoint,data[closestSegment].segmentPoint))
        end 

        if VecDot(dirToNextSegment,dirToBirb) >= 0 and closestSegment ~= 1 then 
            closestSegment = closestSegment - 1
        end
      DebugLine(data[closestSegment].segmentPoint,bird.transform.pos)
        local pos, index = findClosestPointOnPath(closestSegment)
       -- DebugLine(pos,GetPlayerPos())
       DebugLine(pos,bird.transform.pos,1,0,0,1)

        DebugLine(pathData[1].startPos,data[1].segmentPoint,1,1,0,1)
        for j=1, #data do 
            DebugCross(data[j].segmentPoint)
            AutoTooltip(j,data[j].segmentPoint)
        end
        DebugPrint(closestSegment)
      
       
        -- Add start and end pos here
        for j=1, #data do 
            for i=1,#data[j].segmentPathPoints do
                local path = data[j].segmentPathPoints
                if i ~= #path then
                    --DebugLine(curve[i],GetPlayerPos())
                    DebugLine(path[i].pos,path[i+1].pos,1,1,0,1)
                    DebugCross(path[i].pos)
                  --  AutoTooltip("point".. i .. " of segement".. j,path[i].pos)
                    --DrawSprite(ringSprite,Transform(path[i].pos,QuatLookAt(path[i].pos,path[i+1].pos)),path[i].radius,path[i].radius,1,1,1,1)
                end
            end
        end
      --  DebugLine(path[#path].pos,pathData[1].endpos,1,1,0,1)
    end
end

function flight()
    --AutoInspectWatch(pathFind,"path",1," ",false)
     if state.randomEvent == "foundFlightPath" then
         local closestSegment = returnClosestSegment()
         local data = pathData[1].segment
         local closestSegmentData = data[closestSegment].segmentPathPoints
 
         local dirToBirb, dirToNextSegment 
         if closestSegment ~= #data then 
             dirToBirb = VecNormalize(VecSub(data[closestSegment].segmentPoint,bird.transform.pos))
             dirToNextSegment = VecNormalize(VecSub(data[closestSegment+1].segmentPoint,data[closestSegment].segmentPoint))
         end 
 
         if VecDot(dirToNextSegment,dirToBirb) >= 0 and closestSegment ~= 1 then 
             closestSegment = closestSegment - 1
         end
         local pos, index = findClosestPointOnPath(closestSegment)

         DebugWatch("index",index)
         DebugWatch("clos",closestSegment)
        if index ~= #closestSegmentData then
            pos = closestSegmentData[index+1].pos
            DebugPrint("asd")
        else 
            pos = data[closestSegment+1].segmentPathPoints[1].pos
        end
         ConstrainPosition(bird.body,0,bird.transform.pos,pos,5)
        
         -- Add start and end pos here
         for j=1, #data do 
             for i=1,#data[j].segmentPathPoints do
                 local path = data[j].segmentPathPoints
                 if i ~= #path then
                     --DebugLine(curve[i],GetPlayerPos())
                     DebugLine(path[i].pos,path[i+1].pos,1,1,0,1)
                     DebugCross(path[i].pos)
                   --  AutoTooltip("point".. i .. " of segement".. j,path[i].pos)
                     --DrawSprite(ringSprite,Transform(path[i].pos,QuatLookAt(path[i].pos,path[i+1].pos)),path[i].radius,path[i].radius,1,1,1,1)
                 end
             end
         end
       --  DebugLine(path[#path].pos,pathData[1].endpos,1,1,0,1)
     end
 end

function findClosestPointOnPath(closestSegment)

    if not closestSegment then
        return nil  -- No closest segment found
    end

    local points = pathData[1].segment[closestSegment].segmentPathPoints
    local closestPoint = nil
    local closestDist = 20000
    local index = 0
    
    for i = 1, #points do
        local pos = points[i].pos
        local dist = AutoVecDist(pos, bird.transform.pos)
       
        if dist < closestDist then
            closestDist = dist
            closestPoint = pos
            index = i
        end
    end

    return closestPoint, index
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

        DebugPrint(GetTime())
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
        local min,max = GetBodyBounds(GetWorldBody())
        local startPos = bird.transform.pos
        local endPos
        for i=1,10 do 
            local randomPos = Vec(math.random(min[1],max[1]),math.random(min[2],max[2]),math.random(min[3],max[3]))
            local hit,dist = QueryRaycast(randomPos,Vec(0,-1,0),200,0,false)
            endPos = VecAdd(randomPos,VecScale(Vec(0,-1,0),dist-1))
            if hit then break end
        end
        requestFlyPath(startPos,endPos)
        eventReset()
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
        if InputDown("r") then
            wingAnimation()
        else 
            ConstrainOrientation(wing.body, 0, wing.transform.rot, wing.currentWingRot, 10)
        end
    end
end

function birdMovement()
    --ConstrainOrientation(bird.body,0,bird.transform.rot,Quat(),10,10)

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

  --  local playerFwd = TransformToParentVec(GetPlayerTransform(), Vec(0, 0, -1))
  --  local cross = VecCross(playerFwd, bird.up)
  --  local dot = 0.5 - VecDot(bird.fwd, playerFwd)
  --  print(dot)
  --  DebugLine(bird.transform.pos, VecAdd(bird.transform.pos, cross))
  --  ConstrainAngularVelocity(bird.body, 0, cross, dot, -10, 10)

    DebugLine(bird.transform.pos,VecAdd(bird.transform.pos,bird.fwd))
end

function wingAnimation()
    local wingSpeed = 10

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
        ConstrainOrientation(wing.body, 0, wing.transform.rot, rot, 10)
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

function draw(dt)
    debug()
end



-------------# Path Finding API #--------------

function requestFlyPath(strpos,endpos)

    local id = generateNewId()
    local listener = "pathRecieve"..id

    RegisterListenerTo(listener,"pathRecieve")

    local data = {}
    data.id = id
    pathData[#pathData+1] = {}
    pathData[#pathData].startPos = strpos
    pathData[#pathData].endpos = endpos

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
        DebugPrint("The provided path was nil. Requesting another path")
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
--
    if #knots > 3 then
        pathData[#pathData].segment = buildCardinalSpline(knots,14,dataPath)
        state.randomEvent = "foundFlightPath"
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

    local magicNumber = 4.1
    for i=1, #knots do
        local index = #curve+1
        curve[index] = {}
        curve[index].segmentPoint = knots[i+1]
        curve[index].segmentPathPoints = {} 
        if i ~= #knots-2 then 
            -- # Hermite to bezier conversion https://youtu.be/jvPPXbo87ds?t=2528
            local velocity = VecSub(knots[i+2],knots[i])
            local controllPoint1 = VecScale(velocity,1/magicNumber)
            local velocityKnos2 = VecSub(knots[i+3],knots[i+1])
            local controllPoint1Knot2 = VecScale(velocityKnos2,1/magicNumber)
            local controllPoint2 = VecAdd(knots[i+2],VecScale(controllPoint1Knot2,-1))
            for j=1, precision do 
               -- DebugLine(controllPoint1,GetPlayerPos())
                curve[index].segmentPathPoints[#curve[index].segmentPathPoints+1] = {}
                curve[index].segmentPathPoints[#curve[index].segmentPathPoints].pos = bezierFast({knots[i+1],VecAdd(knots[i+1],controllPoint1),controllPoint2,knots[i+2]},j/precision)
                curve[index].segmentPathPoints[#curve[index].segmentPathPoints].radius = AutoLerp(data[i].pos[2]-data[i].max[2],data[i+1].pos[2]-data[i+1].max[2],j/precision)
            end
        else 
            break
        end
    end
    table.remove(curve,#curve)

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

