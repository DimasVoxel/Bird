function init()
    for i=1,40 do 
      
        local min,max = GetBodyBounds(GetWorldBody())
        QueryRequire("physical static large")
        local pos = Vec(math.random(min[1],max[1]),math.random(min[2],max[2]),math.random(min[3],max[3]))
        local hit,dist = QueryRaycast(pos,Vec(0,-1,0),200,0,false)
        local hitpoint = VecAdd(pos,VecScale(Vec(0,-1,0),dist-3))
        if hit and IsPointInWater(hitpoint) == false then
           
            Spawn("MOD/Birds/pigon.xml",Transform(hitpoint),false)
        end
    end
end