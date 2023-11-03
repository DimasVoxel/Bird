#include ./Automatic.lua

function init()
    birdInit()
end

function birdInit()
    bird = {}
    bird.body = FindBody('bird',false)
    bird.transform = GetBodyTransform(bird.body)
    bird.fwd = TransformToParentVec(bird.transform,Vec(0,0,-1))
    bird.allShapes = FindShapes("",false)
    bird.status = ""

    bird.wings = {}
    local wings = FindShapes("wing")

    local p = FindLocation("wingAxis")
    local t = GetLocationTransform(p)
    bird.wingAxisLocalTransform = TransformToLocalTransform(bird.transform,t)

    for i=1,#wings do 
        local shape = wings[i]
        bird.wings[#bird.wings+1] = {}
        bird.wings[#bird.wings].shape = shape
        if HasTag(shape,"left") then 
            bird.wings[#bird.wings].side = "left"
            bird.wings[#bird.wings].xoffset = tonumber(GetTagValue(shape,"xOffset"))/10*-1
        else 
            bird.wings[#bird.wings].side = "right" 
            bird.wings[#bird.wings].xoffset = tonumber(GetTagValue(shape,"xOffset"))/10
        end 

        bird.wings[#bird.wings].localTransform = GetShapeLocalTransform(shape)
        bird.wings[#bird.wings].restPosition = GetShapeLocalTransform(shape)
        bird.wings[#bird.wings].yoffset = tonumber(GetTagValue(shape,"yOffset"))/10
        bird.wings[#bird.wings].zoffset = tonumber(GetTagValue(shape,"zOffset"))/10
        
    end
end

function birdUpdate()
    bird.transform = GetBodyTransform(bird.body)
    bird.fwd = TransformToParentVec(bird.transform,Vec(0,0,-1))
    bird.wingAxis = TransformToParentTransform(bird.transform,bird.wingAxisLocalTransform)
    local com = GetBodyCenterOfMass(bird.body)
    bird.com = TransformToParentPoint(bird.transform, com)

    for i=1,#bird.wings do 
        local wing = bird.wings[i]
        bird.wings[i].localTransform = GetShapeLocalTransform(wing.shape)
    end

    wingAnimation()
  -- AutoQueryRejectShapes(bird.allShapes)
  -- local hit, dist, normal, shape = QueryRaycast(bird.transform.pos,bird.fwd,10,0.5,true)
  -- if hit then DebugPrint("asd") end
  -- DebugCross(VecAdd(bird.transform.pos,VecScale(bird.fwd,dist)))
  -- DebugLine(bird.transform.pos,VecAdd(bird.transform.pos,VecScale(bird.fwd,dist)))
end

function wingAnimation()
    local wingSpeed = 10
    local yOffset = -78
    local xOffset = 55

    local flapOffset = 0
    local flapMagnitude = 70
    local animationFlap = math.sin(GetTime()*wingSpeed)*flapMagnitude+flapOffset

    for i=1, #bird.wings do 
        local wing = bird.wings[i]
        local xOffsetValue = xOffset
        local yOffsetValue = yOffset

        if wing.side == "right" then
            xOffsetValue = xOffsetValue*-1 
            yOffsetValue = yOffsetValue*-1
        end

        local localAxisTransform = TransformToLocalTransform(bird.wingAxisLocalTransform, wing.restPosition)
        localAxisTransform.pos = VecAdd(QuatRotateVec(QuatEuler(xOffsetValue, yOffsetValue, animationFlap), localAxisTransform.pos),Vec(wing.zoffset,wing.yoffset,wing.xoffset))
        localAxisTransform.rot = QuatRotateQuat(QuatEuler(xOffsetValue, yOffsetValue, animationFlap), localAxisTransform.rot)
        SetShapeLocalTransform(wing.shape, TransformToParentTransform(bird.wingAxisLocalTransform, localAxisTransform))
    end
end

function findPathToSky()
    if true then
        local danger = GetPlayerTransform()
        local birdPos = Vec(bird.transform.pos[1],0,bird.transform.pos[3])
        local dangerPos = Vec(danger.pos[1],0,danger.pos[3])

        local dir = VecNormalize(VecSub(birdPos,dangerPos))
        local antiDangerDir = VecNormalize(Vec(dir[1],10,dir[3]))
        
        ConstrainVelocity(bird.body,0,bird.com,antiDangerDir,5)

        DebugLine(bird.transform.pos,VecAdd(VecScale(antiDangerDir,5),bird.transform.pos))

        --local cross = 
        --AutoQueryRejectShapes(bird.allShapes)
        --local hit, dist, normal, shape = QueryRaycast(bird.transform.pos,bird.fwd,10,0.5,true)


    end
end

function pathFinding()
    
end

function tick(dt)
    birdUpdate()
   -- findPathToSky()
    pathFinding()
end



function update(dt)
    
end


function draw(dt)
end


