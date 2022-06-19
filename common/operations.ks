
global sciencePartNames to list(
    "sensorBarometer",
    "sensorThermometer",
    "gooExperiment"
).

function doScience {
    local mods to scienceModules.

    for m in mods:values {
        m[0]:deploy().
    }

    wait 5.

    local eruPart to ship:partsdubbedpattern("Experiment Return")[0].
    local eru to eruPart:getmodule("ModuleScienceContainer").
    until eru:hasevent("container: collect all") {
        wait 0.
    }
    eru:doevent("container: collect all").
    
    wait 1.

    for m in mods:values {
        // duplicates
        m[0]:dump().
    }
}

function scienceModules {
    local scienceMods to Lexicon().
    for pname in sciencePartNames {
        local parts to ship:partsdubbed(pname). 
        local mods to List().
        for p in parts {
            local sciMod to p:getmodule("ModuleScienceExperiment").
            if not (sciMod:inoperable or sciMod:hasdata) {
                mods:add(sciMod).
            }
        }
        if mods:length() > 0 {
            set scienceMods[pname] to mods.
        }
    }
    return scienceMods.
}

function waitWarp {
    parameter endTime.
    kuniverse:timewarp:warpto(endTime).
    wait until time:seconds > endTime.
    wait until ship:unpacked.
}

function waitWarpPhsx {
    parameter endTime.
    set kuniverse:timewarp:mode to "PHYSICS".
    kuniverse:timewarp:warpto(endTime).
    wait until time:seconds > endTime.
    kuniverse:timewarp:cancelwarp.
}

function keyOrDefault {
    parameter lex, k, def.
    if not lex:hasKey(k) {
        set lex:k to def.
    }
    return lex:k.
}