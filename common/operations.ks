@LAZYGLOBAL OFF.

function opsRefuel {
    local shipResources to list().
    list resources in shipResources.
    local transfers to list().
    local refillers to ship:partstaggedpattern("refiller").
    local refillees to ship:partstaggedpattern("refillee").

    for res in shipResources {
        local trans to transferAll(res:name, refillers, refillees).
        set trans:active to true.
        transfers:add(trans).
    }

    until false {
        local anyTransferring to false.
        for trans in transfers {
            if trans:status = "Transferring" {
                set anyTransferring to true.
            }
        }

        if not anyTransferring {
            break.
        }

        wait 0.
    }

    print "Transfer Statuses: ".
    for trans in transfers {
        print " " + trans:resource + ": (" + trans:status + ") " + trans:message.
    }

    local full to opsCheckFull(refillees).
    return full.
}

function opsCheckFull {
    parameter parts.
    for part in parts {
        for resource in part:resources {
            if resource:amount < .99 * resource:capacity {
                print "Out of " + resource:name.
                return false.
            }
        }
    }
    return true.
}

global anytimeScienceParts to list(
    "sensorBarometer",
    "sensorThermometer",
    "sensorAccelerometer",
    "sensorGravimeter",
    "cupola-telescope"
).
global spaceScienceParts to list(
    "magnetometer",
    "InfraredTelescope"
).

global useOnceScienceParts to list(
    "goo",
    "science.module",
    "greenhouse"
).

global labs to list(
    "lab"
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
    kuniverse:timewarp:warpto(detimestamp(endTime)).
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

function maxPartStage {
    local allparts to list().
    list parts in allparts.
    local maxPart to 0.
    for p in allparts {
        if p:stage > maxPart {
            set maxPart to p:stage.
        }
    }
    return maxPart.
}

function stageTo {
    parameter limit.
    until ship:stagenum <= limit {
        wait 0.1.
        stage.
        wait 0.1.
    }
}

function stageToMax {
    stageTo(maxPartStage()).
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
    wait 0.
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

function getPort {
    parameter s.
    local primarySearch to s:partstagged("primaryport"). 
    if primarySearch:length() > 0 {
        return primarySearch[0].
    }
    return s:dockingPorts[0].
}

function groundAlt {
    local galt to altitude - terrainHAt(ship:position).
    return galt.
}

function terrainHAt {
    parameter p.
    local ground to body:geopositionof(p):terrainheight.
    if body:hasOcean() {
        set ground to max(ground, 0).
    }
    return ground.
}

function clearAll {
    clearscreen.
    sas off.
    clearVecDraws().
    clearGuis().
}

function setFlaps {
    parameter val.

    local all to list().
    list parts in all.
    local controlMod to "FARControllableSurface".
    local setting to "flap setting".
    local inc to "increase flap deflection".
    local dec to "decrease flap deflection".
    for i in range(3) {
        for p in all {
            if p:hasmodule(controlMod) {
                local mod to p:getmodule(controlMod).
                if mod:hasfield(setting) {
                    local cur to mod:getfield(setting).
                    if cur > val {
                        mod:doaction(dec, true).
                    }
                    if cur < val {
                        mod:doaction(inc, true).
                    }
                }
            }
        }
        wait 0.
    }
}

global kUnset to "UNSET".
global kForward to "FORWARD".
global kReverse to "REVERSE".
// local reverserState to kUnset.
local allReverserCache to false.
function setThrustReverser {
    parameter state.

    // if reverserState = state {
    //     return allReverserCache.
    // }
    // set reverserState to state.

    local allReversers to true.
    local all to list().
    list engines in all.
    local reverseMod to "ModuleAnimateGeneric".
    for p in all {
        if p:hasmodule(reverseMod) {
            local mod to p:getmodule(reverseMod).
            if state = kForward {
                local event to "forward thrust".
                if mod:hasevent(event) {
                    mod:doevent(event).
                }
            }
            if state = kReverse {
                local event to "reverse thrust".
                if mod:hasevent(event) {
                    mod:doevent(event).
                }
            }
        } else {
            set allReversers to false.
        }
    }
    set allReverserCache to allReversers.
    return allReversers.
}

setThrustReverser(kForward).