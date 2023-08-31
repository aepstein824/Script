@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").

global kWarpCancelDur to 5.

function opsRefuel {
    local transfers to list().
    local refillers to ship:partstaggedpattern("refiller").
    local refillees to ship:partstaggedpattern("refillee").

    local resMap to lexicon().
    for part in refillees {
        for res in part:resources {
            set resMap[res:name] to true.
        }
    }
    local shipResources to resMap:keys.

    for resName in shipResources {
        local trans to transferAll(resName, refillers, refillees).
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
        print " " + trans:resource + ": ("
            + trans:status + ") " + trans:message.
    }

    local full to opsCheckFull(refillees).
    return full.
}

function opsCheckFull {
    parameter parts.
    for part in parts {
        for resource in part:resources {
            if resource:amount < .99 * resource:capacity {
                print " Out of " + resource:name.
                return false.
            }
        }
    }
    return true.
}

global anytimeScienceParts to list(
    "sensorBarometer",
    "sensorThermometer",
    "cupola-telescope"
).
global inertialScienceParts to list(
    "sensorGravimeter"
).
global spaceScienceParts to list(
    "magnetometer"
).
global highSpaceScienceParts to list(
    "InfraredTelescope"
).
global groundOnlyScienceParts to list(
    "sensorAccelerometer"
).
global atmoOnlyScienceParts to list(
    "sensorAtmosphere"
).
global useOnceScienceParts to list(
    "goo",
    "science.module",
    "greenhouse"
).

global labs to list(
    "lab"
).

global scienceModName to "ModuleScienceExperiment".

function sciencePartNames {
    parameter useOnce.
    local names to anytimeScienceParts.
    if useOnce {
        set names to mergeList(names, useOnceScienceParts).
    }
    if status <> "FLYING" {
        set names to mergeList(names, inertialScienceParts).
    }
    if status = "LANDED" or status = "PRELAUNCH" {
        set names to mergeList(names, groundOnlyScienceParts).
        if body:atm:exists {
            set names to mergeList(names, atmoOnlyScienceParts).
        }
    }
    if status = "ORBITING" or status = "ESCAPING" or status = "DOCKED" {
        set names to mergeList(names, spaceScienceParts).
        if periapsis > 250001 {
            set names to mergeList(names, highSpaceScienceParts).
        }
    }
    if status = "FLYING" {
        set names to mergeList(names, atmoOnlyScienceParts).
    }
    return names.
}

function doAnytimeScience {
    local names to sciencePartNames(false).
    local mods to scienceModules(names).

    opsScienceToBox(mods).
}

function doUseOnceScience {
    local names to sciencePartNames(true).
    local mods to scienceModules(names).
    
    opsScienceToBox(mods).
}

function opsScienceToBox {
    parameter mods.

    opsCleanModules(mods).
    opsExperimentModules(mods).
    opsAwaitModules(mods).
    local hasBox to opsCollectScience().
    if hasBox {
        opsCleanModules(mods).
    }
    wait 1.
}

function opsExperimentModules {
    parameter mods.

    for m in mods {
        m:deploy().
        wait 0.
    }
}

function opsAwaitModules {
    parameter mods.
    local start to time:seconds.
    for m in mods {
        wait until m:hasData or ((time:seconds - start) > 15).
    }
    wait 1.
}

function opsCollectScience {
    local eruPattern to "ScienceBox|Experiment Return".
    local eruParts to ship:partsdubbedpattern(eruPattern).
    local hasBox to false.
    for eruPart in eruParts {
        print " Collecting experiments in " + eruPart:name.
        local eru to eruPart:getmodule("ModuleScienceContainer").
        eru:doaction("collect all", true).
        wait 0.
        set hasBox to true.
    }
    return hasBox.
}

function opsCollectRestoreScience {
    opsCollectScience().
    opsCleanModules(ship:modulesnamed(scienceModName)).
}

function opsCleanModules {
    parameter modList.
    for m in modList {
        cleanModule(m).
    }
}

function scienceModules {
    parameter scienceParts.
    local scienceMods to Lexicon().

    for part in ship:parts() {
        if part:hasmodule(scienceModName) {
            local module to part:getmodule(scienceModName).
            if module:hasaction("Crew Report") {
                set scienceMods[part:name] to module.
            }
        }
    }

    for pname in scienceParts {
        local parts to ship:partsdubbedpattern(pname). 
        for p in parts {
            local sciMod to p:getmodule(scienceModName).
            if not (sciMod:inoperable or sciMod:hasdata) {
                set scienceMods[pname] to sciMod.
                break.
            }
        }
    }
    print "Doing science with: " + opsCommaList(scienceMods:keys) + ".".
    return scienceMods:values.
}

function waitWarp {
    parameter endTime.
    local warper to kuniverse:timewarp.

    local lightStack to lights.
    lights off.

    // print " Begin waitWarp to " + endTime.
    wait until warper:issettled.
    set warper:mode to "RAILS".

    local function remaining {
        return detimestamp(endTime - time).
    }
    if remaining() <= 0 return.

    until false {
        kuniverse:timewarp:warpto(detimestamp(endTime)).
        if remaining() < 10 {
            break.
        }
        wait 10.
        if warper:warp > 0 {
            break.
        }
    }

    wait until remaining() <= 0.
    wait until warper:issettled.
    wait until ship:unpacked.
    wait 1.

    if lightStack lights on.
    // print " End waitWarp to " + endTime.
}

function waitWarpPhsx {
    parameter endTime.
    set kuniverse:timewarp:mode to "PHYSICS".
    kuniverse:timewarp:warpto(endTime).
    wait until time:seconds > endTime.
    kuniverse:timewarp:cancelwarp().
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

function opsWarpTillParentAligns {
    parameter align.

    if vang(align, unitY) < 5 {
        return.
    }
    local parent to body:obt:body.
    local currentPos to parent:position - body:position.
    local parentMM to 360 / body:obt:period.
    local norm to normOf(body:obt).

    local negAlign to -1 * align.
    local angleToPosAlign to vectorAngleAround(currentPos, norm, align).
    local angleToNegAlign to vectorAngleAround(currentPos, norm, negAlign).
    local smallerAngleToEither to min(angleToPosAlign, angleToNegAlign).

    local dur to smallerAngleToEither / parentMM.
    waitWarp(time + dur).
}

function opsDecouplePart {
    parameter part.

    local decoupleMods to list(
        "ModuleAnchoredDecoupler",
        "ModuleDecouple"
    ).

    for decoupleMod in decoupleMods {
        if part:hasmodule(decoupleMod) {
            local module to part:getmodule(decoupleMod).
            module:doAction("decouple", true).
        }
    }
}

function keyOrDefault {
    parameter lexi, k, def.
    if not lexi:hasKey(k) {
        set lexi:k to def.
    }
    return lexi:k.
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
    wait 0.
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
    if not lights lights on.
    if not rcs rcs on.
    set ship:control:translation to v(0, 0, 0).
}

function disableRcs {
    if lights lights off.
    if rcs rcs off.
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

function opsListSorted {
    parameter l, compare to { parameter x, y. return x < y. }.

    local out to list().
    for item in l {
        local i to 0.
        until i = out:length or compare(item, out[i]) {
            set i to i + 1.
        }
        out:insert(i, item).
    }
    return out.
}

function opsPortFindPair {
    parameter s.

    local compare to {
        parameter x, y.
        return x:uid < y:uid.
    }.
    local ourPorts to opsListSorted(ship:dockingports, compare).
    local theirPorts to opsListSorted(s:dockingports, compare).
    if ourPorts:empty() or theirPorts:empty() {
        return list().
    }

    // try first to match tags
    for ours in ourPorts { 
        for theirs in theirPorts { 
            if ours:state = "Ready" and theirs:state = "Ready"
                and ours:tag:length <> 0
                and ours:tag = theirs:tag
                and ours:nodetype = theirs:nodetype {
                print " Found port on " + s:name + " with tag " + ours:tag.
                return list(ours, theirs).
            }
        }
    }

    // try without matching tags
    for ours in ourPorts { 
        for theirs in theirPorts { 
            if ours:state = "Ready" and theirs:state = "Ready"
                and ours:nodetype = theirs:nodetype {
                print " Found port on " + s:name.
                return list(ours, theirs).
            }
        }
    }

    return list().
}

function opsControlFromPort {
    parameter port.
    port:getmodule("ModuleDockingNode"):doevent("Control From Here").
}

function groundAlt {
    local galt to altitude - terrainHAt(ship:position).
    return galt.
}

function atmHeightOr0 {
    parameter bod.
    return choose 0 if not bod:atm:exists else bod:atm:height.
}

function opsScienceHeight {
    parameter bod.
    return 20500 + atmHeightOr0(bod).
}

function terrainHAt {
    parameter p.
    return terrainHGeo(body:geopositionof(p)).
}

function terrainHGeo {
    parameter geo.
    local ground to geo:terrainheight.
    if geo:body:hasOcean() {
        set ground to max(ground, 0).
    }
    return ground.
}

function clearAll {
    sas off.
    clearVecDraws().
    clearGuis().
}

function setFlaps {
    parameter val.

    setStockFlaps(val).

    setFARFlaps(val).
}

function setStockFlaps {
    parameter val.

    local parts to ship:partstagged("flap").
    for p in parts {
        local modName to "SyncModuleControlSurface".
        if p:hasmodule(modName) {
            local controlMod to p:getmodule(modName).
            if val < 0.5 {
                controlMod:setfield("deploy", false).
            } else {
                controlMod:setfield("deploy angle", val * 5).
                controlMod:setfield("deploy", true).
            }
        }
    }
    wait 0.
}

function setFARFlaps {
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
                local module to p:getmodule(controlMod).
                if module:hasfield(setting) {
                    local cur to module:getfield(setting).
                    if cur > val {
                        module:doaction(dec, true).
                    }
                    if cur < val {
                        module:doaction(inc, true).
                    }
                }
            }
        }
        wait 0.
    }

}

function opsUndockPart {
    parameter part.
    local elemList to ship:elements.
    for elem in elemList {
        if elem:parts:contains(part) {
            for port in elem:dockingPorts {
                if port:haspartner {
                    port:undock.
                }
                wait 1.
            }
        }
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
            local module to p:getmodule(reverseMod).
            if state = kForward {
                local event to "forward thrust".
                if module:hasevent(event) {
                    module:doevent(event).
                }
            }
            if state = kReverse {
                local event to "reverse thrust".
                if module:hasevent(event) {
                    module:doevent(event).
                }
            }
        } else {
            set allReversers to false.
        }
    }
    set allReverserCache to allReversers.
    return allReversers.
}

function pressAnyKey {
    print "Press ANY key to continue ".
    terminal:input:getchar().
}

function repeatForDuration {
    parameter func, dur.

    local start to time:seconds.
    until time:seconds - start > dur {
        func().
    }
}

function opsCommaList {
    parameter lst.
    local acc to "".
    for item in lst {
        set acc to acc + item + ", ".
    }
    return acc.
}

local astSizes to list("A", "B", "C", "D", "E", "F", "G", "H", "I").
function vesselIsAsteroid {
    parameter vess.

    return astSizes:find(vess:sizeclass) <> -1.
}

function opsDataPath {
    parameter lexiName.
    return "craftData/" + core:tag + "_" + lexiName.

}

function opsDataLoad {
    parameter lexiOut, lexiName.
    local dataPath to opsDataPath(lexiName).
    if not exists(dataPath) {
        print "Load did not find file for " + lexiName.
        return.
    }
    print "Load found file for " + lexiName.
    local craftData to readJson(dataPath).
    for k in craftData:keys{
        set lexiOut[k] to craftData[k].
    }
}

function opsISRU {
    parameter count to 2.

    local opsISRUActions to lex(
        "Oxidizer", "ox",
        "LiquidFuel", "lqdfuel",
        "MonoPropellant", "monoprop"
    ).

    local resList to ship:resources.
    local mayConvert to list().
    local nowConvert to lex().
    local stopActions to lex().
    local oreRes to list().

    // look for mineable fuels
    for res in resList {
        if opsISRUActions:haskey(res:name) {
            mayConvert:add(res).
        }
        if res:name = "Ore" {
            oreRes:add(res).
        }
    }


    // choose and cache isru
    local isruParts to ship:partsnamed("isru").
    if isruParts:length < 1 {
        return.
    }
    local isruPart to isruParts[0].
    local modCount to isruPart:allmodules:length.

    // wait for full fuel
    until false {
        for res in nowConvert:values {
            local proportion to res:amount / res:capacity.
            if proportion > 0.99 {
                print " Finished ISRU for " + res:name.
                stopActions[res:name]().
                stopActions:remove(res:name).
                nowConvert:remove(res:name).
            }
        }
        for res in mayConvert {
            if nowConvert:length >= count {
                break.
            }
            local proportion to res:amount / res:capacity.
            if proportion < 0.95 {
                nowConvert:add(res:name, res).
                local actionSymbol to opsISRUActions[res:name].
                local actionName to "start isru [" + actionSymbol + "]".
                local stopName to "stop isru [" + actionSymbol + "]".
                for i in range(modCount) {
                    local isruMod to isruPart:getmodulebyindex(i).
                    if isruMod:hasaction(actionName) {
                        print " Enabling ISRU for " + res:name.
                        isruMod:doaction(actionName, true).
                        set stopActions[res:name] to {
                            isruMod:doAction(stopName, true).
                        }.
                        break.
                    }
                }
            }
        }
        if nowConvert:length = 0 {
            break.
        }
        waitWarp(time:seconds + 6 * 3600).
        drills off.
        wait 5.
        drills on.
    }
    // wait for full ore
    until false {
        local proportion to oreRes[0]:amount / oreRes[0]:capacity.
        if proportion > 0.99 {
            print " Full Ore".
            break.
        }
        waitWarp(time:seconds + 6 * 3600).
        drills off.
        wait 5.
        drills on.
    }

    kuniverse:timewarp:cancelwarp().
    isru off.
}

function opsISRUMineAll {
    lights off.
    radiators on.
    deployDrills on.
    wait 1.
    drills on.

    opsISRU(2).

    radiators off.
    drills off.
}
