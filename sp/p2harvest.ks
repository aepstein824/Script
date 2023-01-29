@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/operations.ks").
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/dockrecv.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/travel.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/waypoints.ks").

// Mission parameters
local tankTag to "tank".
local shoddleName to "P2 Shoddle".
local amShoddle to core:tag = "shoddle".
local amScooper to core:tag = "scooper".
local amTank to core:tag = tankTag.
local dest to minmus.
local shoddleAlt to 30000.

// setStages().
set kPhases:phase to 8.
set kPhases:startInc to 5.
set kPhases:stopInc to 100.

if shouldPhase(0) {
    setTargetTo(dest).
    if amShoddle {
        print "Launch Shoddle".
        set kClimb:Turn to 5.
        set kClimb:OrbitStage to 1.
        launchQuicksave("p2_shoddle_launch").
    } else if amScooper {
        print "Launch Scooper".
        set kClimb:OrbitStage to 1.
        set kClimb:Turn to 5.
        launchQuicksave("p2_scooper_launch").
    } else if amTank {
        print "Launch Tank".
        set kClimb:OrbitStage to 0.
        launchQuicksave("p2_tank_launch").
    }
    launchToOrbit().
    wait 3.
}
if shouldPhase(1) {
    local travelContext to lexicon(
        "dest", dest,
        "inclination", 90
    ).
    if amShoddle {
        set travelContext:altitude to shoddleAlt.
    } else {
        set travelContext:altitude to dest:soiradius / 3.
    }  
    travelTo(travelContext).
    if not amShoddle {
        local tgt to vessel(shoddleName).
        if amScooper {
            // deorbit the tank that carried us here
            matchPlanesAndSemi(normOf(tgt:orbit), -200).
            nodeExecute().
            lock steering to shipNorm().
            wait 5.
            stageTo(0).
            wait 1.
            local radius to altitude + body:radius.
            local semi to (1.5 * body:radius + tgt:altitude + radius) / 2.
            local spd to orbitalSpeed(body:mu, semi, radius).
            local correctionTime to time + 60.
            local thenV to velocityAt(ship, correctionTime):orbit:mag.
            add node(correctionTime, 0, 0, spd - thenV).
            nodeExecute().
        } else if amTank {
            matchPlanesAndSemi(normOf(tgt:orbit), 2 * tgt:altitude).
            nodeExecute().
        }
        local interceptContext to lexicon(
            "dest", tgt
        ).
        travelTo(interceptContext).
        rcsApproach().
        print " Waiting to dock".
        wait until procCount() > 1.
    }
}
if shouldPhase(2) {
    if amScooper {
        scooperAll().
    }
    if amShoddle {
        dockRecv().
    }
    // tank will wait in stage 3
}
if shouldPhase(3) {
    if amScooper {
        print "Science missions complete".
        opsCollectRestoreScience().
        pressAnyKey().
        local procs to shipProcessors().
        // The scooper makes the decision because it knows when it's done. The
        // alternative would be messages or the tank knowing if it's empty.
        // Messages would be more work, and the tank may not actually be empty.
        for p in procs {
            if p:part:tag = tankTag {
                opsUndockPart(p:part).
            }
        }
        opsUndockPart(core:part).
        wait 2.
        set kuniverse:activevessel to vessel(shoddleName).
        orbitDispose().
    }
    if amTank {
        print "Tank waiting for ejection".
        wait until procCount() = 1.
        orbitDispose().
    }
    if amShoddle {
        print "Shoddle waiting for tank to be ejected".
        wait until procCount() = 1.
        print "Shoddle returns home".
        shipControlFromCommand().
    }
}
if shouldPhase(4) and amShoddle {
    until false {
        escapePrograde(-100, 20).
        wait 0.
        if orbitPatchesInclude(nextNode:orbit, mun) {
            remove nextNode.
            waitWarp(time:seconds + orbit:period).
        } else {
            nodeExecute().
            break.
        }
    }
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}
if shouldPhase(5) and amShoddle{
    circleAtKerbin().
}
if shouldPhase(6) and amShoddle {
    landPlaneDeorbit().
}
if shouldPhase(7) and amShoddle {
    landPlaneReentry().
}
if shouldPhase(8) and amShoddle {
    landPlaneRunway().
}

local function setStages {
    if status = "PRELAUNCH" {
        if amScooper {
            set kPhases:startInc to 0.
            set kPhases:stopInc to 100.
            return.
        }
        set kPhases:startInc to 0.
        set kPhases:stopInc to 1.
        return.
    } 
    if body = dest {
        set kPhases:startInc to 2.
        set kPhases:stopInc to 100.
        return.
    }
}

local function scooperAll {
    local lzList to lzList().

    for lz in lzList {
        scooperIteration(lz).
    }
}

local function scooperIteration {
    parameter lz.
    // start docked to the fleet

    print "Scooper iteration for " + lz.
    print " Restoration and refuel".
    opsCollectRestoreScience().
    opsRefuel().
    wait 1.

    print " Undock".
    opsUndockPart(core:part).
    orbitSeparate(3, vessel(shoddleName)).
    set kuniverse:activevessel to core:vessel.
    wait 1.


    print "Landing".
    local flatLz to vacNearestFlat(lz).
    vacDescendToward(flatLz).
    lights on.
    vacLandGeo(flatLz).
    print " Landed at " + ship:geoposition.

    doUseOnceScience().

    local home to vessel(shoddleName).
    setTargetTo(home).
    lights off.
    print " Lifting off " + body:name.
    local alti to 1.1 * home:altitude.
    waitForTargetPlane(home).
    vacClimb(alti, launchHeading()).
    circleNextExec(alti).

    print " Rndv with " + home:name.
    local travelCtx to lexicon("dest", home).
    travelTo(travelCtx).
    rcsApproach().

    wait until procCount() > 1.
}

local function lzList {
    parameter firstTrip to true.

    if dest = mun {
        if firstTrip {
            return list(
                dest:geopositionlatlng(-73, 33), // Poles
                dest:geopositionlatlng(-82, 65), // Polar Lowlands
                dest:geopositionlatlng(65 ,-22), // Polar Crater
                dest:geopositionlatlng(-59, 55), // High
                dest:geopositionlatlng(-69, 57), // High Crater
                dest:geopositionlatlng(-45, 45), // Mid
                dest:geopositionlatlng(-53, 44), // Mid Crater
                dest:geopositionlatlng(-36, 44)  // Low
            ).
        } else {
            return list(
                dest:geopositionlatlng(53, 40),  // NE Basin
                dest:geopositionlatlng(13, 25),  // NW Crater
                dest:geopositionlatlng(0, -140), // E Far Crater
                dest:geopositionlatlng(0, -135), // Canyon
                dest:geopositionlatlng(7, -49),  // Far Crater
                dest:geopositionlatlng(-11, 90), // E Crater
                dest:geopositionlatlng(-20, 135),// Twins
                dest:geopositionlatlng(-42, 10)  // SW Crater
            ).
        }
    }
    if dest = minmus {
        return list(
            dest:geopositionlatlng(89, -30),  // Poles
            dest:geopositionlatlng(57, 31),   // Low
            dest:geopositionlatlng(-7, 29),   // Mid
            dest:geopositionlatlng(64, -112), // High
            dest:geopositionlatlng(-22, 172), // Flats
            dest:geopositionlatlng(33, 178),  // Lesser
            dest:geopositionlatlng(-6, -92),  // Great
            dest:geopositionlatlng(-5, -7)    // Greater
        ).
    }
}