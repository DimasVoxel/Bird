function init()
    once = false
end

function tick()
    if once == false then 
        once = true 
        Spawn('<script pos="0.0 0.2 0.0" file="MOD/pathFInderLoadingScreen.lua"/>',Transform())
    end
end