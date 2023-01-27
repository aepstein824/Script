@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/travel.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/waypoints.ks").

// Mission parameters
local amShoddle to core:tag = "shoddle".
local amScooper to core:tag = "scooper".
local amTank to core:tag = "tank".
local dest to mun.
local shoddleAlt to 30000.

setStages().
// set kPhases:phase to 1.

if shouldPhase(0) {
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
        "dest", mun,
        "inclination", 90
    ).
    if amShoddle {
        set travelContext:altitude to shoddleAlt.
    } else {
        set travelContext:altitude to dest:soiradius / 3.
    }  
    travelTo(travelContext).
    if not amShoddle {
        local tgt to vessel("P2 Shoddle").
        if amScooper {
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
    }
}
if shouldPhase(2) {
    if amScooper {
        opsCollectRestoreScience().
        opsRefuel().
    }
}

local function setStages {
    if status = "PRELAUNCH" {
        set kPhases:startInc to 0.
        set kPhases:stopInc to 1.
        return.
    } 
    if body = dest {
    

    }
}