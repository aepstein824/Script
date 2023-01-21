@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

global kWarpCancelDur to 5.

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
    "sensorGravimeter",
    "cupola-telescope"
).
global spaceScienceParts to list(
    "magnetometer",
    "InfraredTelescope"
).
global groundOnlySceinceParts to list(
    "sensorAccelerometer"
).
global useOnceScienceParts to list(
    "goo",
    "science.module",
    "greenhouse"
).

global labs to list(
    "lab"
).

function doAnytimeScience {
    local anytime to anytimeScienceParts.
    local mods to scienceModules(anytime).

    opsScienceToBox(mods).
}

function doUseOnceScience {
    local useOnce to mergeList(anytimeScienceParts, useOnceScienceParts).
    local mods to scienceModules(useOnce).
    
    opsScienceToBox(mods).
}

function opsScienceToBox {
    parameter mods.

    opsExperimentModules(mods).
    opsAwaitModules(mods).
    opsCollectScience().
    opsCleanModules(mods).
}

function opsExperimentModules {
    parameter mods.

    for m in mods:values {
        m[0]:deploy().
        wait 0.
    }
}

function opsAwaitModules {
    parameter mods.
    for m in mods:values {
        wait until m[0]:hasData.
    }
    wait 0.
}

function opsCollectScience {
    local eruPattern to "ScienceBox|Experiment Return".
    local eruParts to ship:partsdubbedpattern(eruPattern).
    for eruPart in eruParts {
        print " Collecting experiments in " + eruPart:name.
        local eru to eruPart:getmodule("ModuleScienceContainer").
        eru:doaction("collect all", true).
        wait 0.
    }
}

function opsCleanModules {
    parameter mods.
    for m in mods:values {
        cleanModule(m[0]).
    }
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
    wait kWarpCancelDur.
    wait until ship:unpacked.
}

function waitWarpPhsx {
    parameter endTime.
    set kuniverse:timewarp:mode to "PHYSICS".
    kuniverse:timewarp:warpto(endTime).
    wait until time:seconds > endTime.
    kuniverse:timewarp:cancelwarp.
}

function opsGetSunAngle {
    parameter geo.
    local sunPos to sun:position - body:position.
    local geoPos to geo:position - body:position.
    local currentSunAngle to vectorAngleAround(sunPos, unitY, geoPos).
    return currentSunAngle.
}

// Warp till the geo position is at the specified sun angle. Zero is noon.
// I take a geo pos here to make clear that we're using the body's rotation.
function opsWarpTillSunAngle {
    parameter geo, sunAngle.

    local currentSunAngle to opsGetSunAngle(geo).
    local bodyMM to -body:angularvel:y * constant:radtodeg.
    local around to posAng(sunAngle - currentSunAngle).
    local dur to around / bodyMM.

    waitWarp(time + dur).
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

function unsetTarget {
    set target to body.
    wait 0.
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

    // remove duplicates
    m:dump().
    wait 0.
    if not m:inoperable {
        m:reset().
    }
    for action in m:allactionnames {
        if action:contains("reset") {
            print " Attempting reset of " + m:part:name.
            m:doaction(action, true).
        }
    }
    wait 0.
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
local reverserState to kUnset.
local allReverserCache to false.
function setThrustReverser {
    parameter state.

    if reverserState = state {
        return allReverserCache.
    }
    set reverserState to state.

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
