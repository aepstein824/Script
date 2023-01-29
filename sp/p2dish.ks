@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/landAtm.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/airline.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/travel.ks").

// Mission parameters
local normIndex to 2.
local dest to minmus.
local fixingDur to 10.
local radMultiplier to 2.5.
local returnStage to 1.

// Orbits
local captureInc to vang(unitY, dishNorm()).
local destRad to dest:radius.
local ringSemi to destRad * radMultiplier.
local ringPeriod to orbitalSemiToPeriod(dest:mu, ringSemi).
local dispensePeriod to 5/3 * ringPeriod.
local dispenseSemi to orbitalPeriodToSemi(dest:mu, dispensePeriod).
local dispenseAp to  2 * dispenseSemi - ringSemi - dest:radius.
local ringAlt to ringSemi - destRad.

// Testing
// set kPhases:phase to 2.

// Launch
set kClimb:OrbitStage to 4.

local amDish to core:tag <> "dispenser".
if amDish {
    set kPhases:phase to 5.
} else if kPhases:phase < 0 {
    local count to procCount().
    wait 1.
    if count = 4 {
        pressAnyKey().
        set kPhases:startInc to 0.
        set kPhases:stopInc to 4.
    } else if count > 1 {
        set kPhases:startInc to 4.
        set kPhases:stopInc to 4.
    } else {
        set kPhases:startInc to 6.
        set kPhases:stopInc to 8.
    }
}

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("p2_dish_launch").
    launchToOrbit().
    wait 3.
}
if shouldPhase(1) {
    local travelContext to lexicon(
        "dest", dest,
        "altitude", dispenseAp,
        "inclination", captureInc
    ).
    travelTo(travelContext).
}
if shouldPhase(2) {
    local solarNorm to dishNorm().
    if vdot(solarNorm, shipNorm()) < 0 {
        set solarNorm to solarNorm * -1.
    }
    matchPlanesAndSemi(solarNorm, ringAlt).
    nodeExecute().
    orbitTunePeriod(dispensePeriod, fixingDur).
    print " orbit error " + (obt:period - dispensePeriod).
    print " norm error " + vang(shipNorm(), solarNorm).
    opsWarpTillParentAligns(solarNorm).
}
if shouldPhase(4) {
    waitWarp(time:seconds + obt:eta:periapsis - 100).
    wait 5.

    local cores to list().
    list processors in cores.
    local dishProc to cores[0].
    for c in cores {
        if c:part:uid <> core:part:uid {
            set dishProc to c.
            break.
        }
    }

    local decoupler to dishProc:part:decoupler.
    opsDecouplePart(decoupler).
    wait 2.
    set kuniverse:activevessel to dishProc:part:ship.
}
if shouldPhase(5) and amDish and obt:eccentricity > 0.05 {
    wait 1.
    core:doevent("Close Terminal").
    wait until procCount() = 1.
    core:doevent("Open Terminal").
    wait until ship = kuniverse:activevessel.
    wait 2.
    print "I'm the active vessel!".
    stageToMax().
    changeApAtPe(ringAlt). 
    nodeExecute().
    orbitTunePeriod(ringPeriod, fixingDur).
    print " orbit error " + (obt:period - ringPeriod).
    waitWarp(time + 300).
    set kuniverse:activevessel to vessel("P2 Dish").
}
if shouldPhase(6) {
    print " Deorbiting transit stage".
    changePeAtAp(-500).
    local dv to nextNode:prograde.
    nodeExecute().
    lock steering to shipNorm().
    wait 5.
    stageTo(returnStage).
    add node(time:seconds + 60, 0, 0, -dv).
    nodeExecute().
}
if shouldPhase(7) {
    circleNextExec(apoapsis).
    escapePrograde(-100).
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    circleAtKerbin().
}
if shouldPhase(8) {
    landKsc().
}

function dishNorm {
    // These must be gotten while orbiting the destination
    if normIndex = 0 {
        return solarPrimeVector.
    } else if normIndex = 1 {
        return vCrs(solarPrimeVector, unitY).
    } else {
        return unitY.
    }
}