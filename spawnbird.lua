function init()

once = false 
end

function tick()
    if once == false then
        once = true
        spawnInit()
        counter = 0
        for i=1,30 do 
            for retry=0,20 do 
                local min,max = GetBodyBounds(GetWorldBody())
                QueryRequire("physical static large")
                local pos = Vec(math.random(min[1],max[1]),math.random(min[2],max[2]),math.random(min[3],max[3]))
                local hit,dist = QueryRaycast(pos,Vec(0,-1,0),200,0,false)
                local hitpoint = VecAdd(pos,VecScale(Vec(0,-1,0),dist-3))
                if hit and IsPointInWater(hitpoint) == false then
                    local XML = getrandom(birds.default.spawnTable,birds.default.totalPercent)
                    Spawn(XML,Transform(hitpoint),false)
                    counter = counter + 1
                    break
                end
            end
        end
    end
end

function spawnInit()
    local function totalPercent(table)
        total = 0
        for i = 1, #table do
          total = total + table[i][2]
        end
        return total
    end

    birds = {
        default = {
            spawnTable = {
                { "MOD/Birds/pigon.xml", 30 },
                { "MOD/Birds/tit.xml", 25 },
                { "MOD/Birds/bluetit.xml", 25 },
                { "MOD/Birds/sparrow.xml", 25 },
                { "MOD/Birds/AmericanRobbin.xml", 20 },
                { "MOD/Birds/Swift.xml",17},
                { "MOD/Birds/House_martin.xml",15},
                { "MOD/Birds/magpie.xml", 15 },
                { "MOD/Birds/Robin.xml",15},
                { "MOD/Birds/crow.xml", 15 },
                { "MOD/Birds/seagull.xml",15},
                { "MOD/Birds/duck.xml",15},
                { "MOD/Birds/Serin.xml",10},
                { "MOD/Birds/GoldFinch.xml",10},
                { "MOD/Birds/Jay.xml",10},
                { "MOD/Birds/kingfisher.xml",8},
                { "MOD/Birds/Green_Woodpecker.xml",6},
                { "MOD/Birds/Red_Velvet.xml",4},
                { "MOD/Birds/pukeko.xml", 3 },
            },
            totalPercent = 0
        },

    }

    for node,table in pairs(birds) do 
        birds[node].totalPercent = totalPercent(table.spawnTable)
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