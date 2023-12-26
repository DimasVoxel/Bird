--[[
#include ../script/Automatic.lua
]]

function init()
    birdInit()
    animationInit()
    stateInit()
end

function stateInit()
    state = {}
    state.randomEvent = ""
    state.randomEventTimer = 0
end

function animationInit()
    animation = {}
    animation.flapSpeed = 0
    animation.flapping = false
    animation.flappingAnimation = 0

    animation.headPecking = false
    animation.headTimer = 0
end

function birdInit()
    bird = {}
    bird.body = FindBody('bird', false)
    bird.transform = GetBodyTransform(bird.body)
    bird.fwd = TransformToParentVec(bird.transform, Vec(0, 0, -1))
    bird.allShapes = FindShapes("", false)
    
    bird.supposedRotation = Quat()
    bird.mass = GetBodyMass(bird.body)

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

function birdUpdate()
    bird.transform = GetBodyTransform(bird.body)
    bird.fwd = TransformToParentVec(bird.transform, Vec(0, 0, -1))
    bird.up = TransformToParentVec(bird.transform, Vec(0, 1, 0))
    bird.wingAxis = TransformToParentTransform(bird.transform, bird.wingAxisLocalTransform)
    local com = GetBodyCenterOfMass(bird.body)
    bird.com = TransformToParentPoint(bird.transform, com)
    bird.status = "roam"

    bird.head.transform = GetBodyTransform(bird.head.body)
    local localTransform = TransformToParentTransform(bird.transform,bird.head.localTransform)
    ConstrainPosition(bird.head.body, bird.body, bird.head.transform.pos, localTransform.pos)

    if InputDown("e") then -- Head Animation 
        local initialQuat = localTransform.rot
        local sideways = TransformToParentVec(bird.head.transform,Vec(-1,0,0))
        local rotateQuat = QuatAxisAngle(sideways,80)
        ConstrainOrientation(bird.head.body,bird.body,bird.head.transform.rot,QuatRotateQuat(rotateQuat,initialQuat))
    else
        ConstrainOrientation(bird.head.body,bird.body,bird.head.transform.rot,localTransform.rot)
    end

    handleWings() -- WingAnimation
    birdMovement()

  -- Old Stand upright code
  --  local cross = VecCross(Vec(0, 1, 0), bird.up)
  --  local dot = 0.5 - VecDot(bird.fwd, Vec(0, 1, 0))
  --  print(dot)
  --  DebugLine(bird.transform.pos, VecAdd(bird.transform.pos, cross))
  --  --ConstrainAngularVelocity(bird.body,0,cross,dot,-10,10)
--
  --  local playerFwd = TransformToParentVec(GetPlayerTransform(), Vec(0, 0, -1))
  --  local cross = VecCross(playerFwd, bird.up)
  --  local dot = 0.5 - VecDot(bird.fwd, playerFwd)
  --  print(dot)
  --  DebugLine(bird.transform.pos, VecAdd(bird.transform.pos, cross))
  --  ConstrainAngularVelocity(bird.body, 0, cross, dot, -10, 10)
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
     --   
    end

end

function birdMovement()
    ConstrainOrientation(bird.body,0,bird.transform.rot,Quat(),10,10)
    if InputPressed("q") then 
        ApplyBodyImpulse(bird.body,bird.com,VecScale(VecAdd(bird.up,bird.fwd),bird.mass*4))
    end
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
        local flap = math.sin(sineInput) * 50 * flip

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
    birdUpdate()
end

function draw(dt)
end
