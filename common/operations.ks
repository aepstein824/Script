@LAZYGLOBAL OFF.

global sciencePartNames to list(
    "sensorBarometer",
    "sensorThermometer",
    "goo",
    "science.module"
).
doScience().

function doScience {
    local mods to scienceModules.

    for m in mods:values {
        m[0]:deploy().
    }

    wait 5.

    local eruPattern to "ScienceBox|Experiment Return".
    local eruPart to ship:partsdubbedpattern(eruPattern)[0].
    local eru to eruPart:getmodule("ModuleScienceContainer").
    eru:doaction("collect all", true).
    
    wait 1.

    for m in mods:values {
        cleanModule(m[0]).
    }
}

function cleanModule {
    parameter m.

    // duplicates
    m:dump().
    // local p to m:part.
    // local doorModName to "ModuleAnimateGeneric".
    // if p:hasmodule(doorModName) {
    //     local doorMod to p:getmodule(doorModName).
    //     local doorActionName to "toggle doors".
    //     if doorMod:hasaction(doorActionName) {
    //         doorMod:doAction(doorActionName, true).
    //     }
    //     local coverActionName to "toggle cover".
    //     if doorMod:hasaction(coverActionName) {
    //         doorMod:doAction(coverActionName, true).
    //     }
    // }
}

function scienceModules {
    local scienceMods to Lexicon().
    for pname in sciencePartNames {
        local parts to ship:partsdubbedpattern(pname). 
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
    set kuniverse:timewarp:mode to "RAILS".
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