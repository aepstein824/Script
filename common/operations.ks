@LAZYGLOBAL OFF.

global anytimeScienceParts to list(
    "sensorBarometer",
    "sensorThermometer",
    "sensorAccelerometer",
    "sensorGravimeter"
).
global spaceScienceParts to list(
    "magnetometer"
).

global useOnceScienceParts to list(
     "goo",
    "science.module"
).

function doAG1To45Science {
    local ag1Parts to anytimeScienceParts.
    local mods to scienceModules(ag1Parts).
    doSearchScience(mods).
    wait 5.
    ag4 off. ag4 on.
    cleanModules(mods).
    wait 3.
    doSearchScience(mods).
    wait 5.
    ag5 off. ag5 on.
    cleanModules(mods).
    wait 3.
}

function doAG13To45Science {
    local ag13Parts to mergeList(anytimeScienceParts, spaceScienceParts).
    local mods to scienceModules(ag13Parts).
    doSearchScience(mods).
    wait 10.
    ag4 off. ag4 on.
    cleanModules(mods).
    wait 10.
    doSearchScience(mods).
    wait 10.
    ag5 off. ag5 on.
    cleanModules(mods).
    wait 10.
}

function doSearchScience {
    parameter mods.

    wait 1.
    for m in mods:values {
        m[0]:deploy().
    }
}

function cleanModules {
    parameter mods.
    for m in mods:values {
        cleanModule(m[0]).
    }
}

function doSearchAndCollect {
    parameter mods.

    doSearchScience(mods).
    wait 5.

    local eruPattern to "ScienceBox|Experiment Return".
    local eruPart to ship:partsdubbedpattern(eruPattern)[0].
    local eru to eruPart:getmodule("ModuleScienceContainer").
    eru:doaction("collect all", true).
}


function scienceModules {
    parameter scienceParts.
    local scienceMods to Lexicon().
    for pname in scienceParts {
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

function mergeLex {
    parameter a, b.
    local merged to a:copy().
    for bk in b:keys {
        set merged[bk] to b[bk].
    }
    return merged.
}

function mergeList {
    parameter a, b.
    local merged to a:copy().
    for bItem in b {
        merged:add(bItem).
    }
    return merged.
}

function stageTo {
    parameter limit.
    until ship:stagenum <= limit {
        wait 0.5.
        stage.
        wait 0.5.
    }
}

function setTargetTo {
    parameter nameOrThing.

    if nameOrThing:typename <> "String" {
        set target to nameOrThing.
    }

    local candidates to list().
    list targets in candidates.

    for c in candidates {
        if c:name = nameOrThing {
            set target to c:name.
        }
    }

    list bodies in candidates.

    for c in candidates {
        if c:name = nameOrThing {
            set target to c:name.
        }
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

function jettisonFairings {
	for part in ship:parts {
		if part:hasmodule("moduleproceduralfairing") {
			local decoupler is part:getmodule("moduleproceduralfairing").
			if decoupler:hasevent("deploy") {
				decoupler:doevent("deploy").
			}
		}
    }
}

function enableRcs {
    rcs on.
    set ship:control:translation to v(0, 0, 0).
}

function disableRcs {
    rcs off.
    set ship:control:translation to v(0, 0, 0).
}

function launchQuicksave {
    parameter name.

    if body = kerbin and status = "PRELAUNCH" {
        kuniverse:quicksaveto(name + "_launch").
    } else {
        print "NON KERBIN DETECTED: SKIPPING QUICKSAVE".
    }
}

function detimestamp {
    parameter t.

    if t:typename = "TimeStamp" or t:typename = "TimeSpan" {
        return t:seconds.
    }
    return t.
}