@LAZYGLOBAL OFF.

// before loading files
local dest to pol.
local amDish to core:tag = "dish".
if amDish and body <> dest {
    core:deactivate().
}

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
local fixingDur to 10.
local radMultiplier to 2.5.
local returnStage to 1.
set kClimb:OrbitStage to 2.
local amDispenser to core:tag = "dispenser".
local dispenserName to "P3 Dish".
local dishCount to ship:partstagged("dish"):length.

// Orbits
local destRad to dest:radius.
local ringSemi to destRad * radMultiplier.
local ringPeriod to orbitalSemiToPeriod(dest:mu, ringSemi).
local dispensePeriod to 5/3 * ringPeriod.
local dispenseSemi to orbitalPeriodToSemi(dest:mu, dispensePeriod).
local dispenseAp to  2 * dispenseSemi - ringSemi - dest:radius.
local ringAlt to ringSemi - destRad.

// Testing
// set kPhases:phase to 0.
setStages().
if amDispenser {
    core:doevent("Open Terminal").
}

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("p3_dish").
    set kClimb:Turn to 10.
    set kClimb:ClimbAp to 120000.
    set kClimb:ClimbPe to 110000.
    launchToOrbit().
    wait 3.
    set ship:name to dispenserName.
    kuniverse:quicksaveto("p3_dish_1").
}
if shouldPhase(1) {
    local travelContext to lexicon(
        "dest", dest,
        "altitude", dispenseAp,
        "inclination", 90
    ).
    travelTo(travelContext).
    doUseOnceScience().
    wait 2.
    kuniverse:quicksaveto("p3_dish_2").
}

if shouldPhase(2) and amDispenser {
    local normIndex to 3 - floor((dishCount + 2.5) / 3).
    print " solar norm " + normIndex.
    local solarNorm to dishNorm(normIndex).
    if vdot(solarNorm, shipNorm()) < 0 {
        set solarNorm to solarNorm * -1.
    }
    if mod(dishCount, 3) = 0 {
        changePeAtAp(apoapsis).
        nodeExecute().
        matchPlanesAndSemi(solarNorm, ringAlt).
        nodeExecute().
        orbitTunePeriod(dispensePeriod, fixingDur).
    }

    waitWarp(time:seconds + obt:eta:periapsis - 100).
    wait 5.

    local cores to list().
    list processors in cores.
    local dishProc to cores[0].
    for c in cores {
        if c:part:tag = "dish" {
            set dishProc to c.
            break.
        }
    }
    dishProc:activate.
    wait 1.
    local decoupler to dishProc:part:decoupler.
    opsDecouplePart(decoupler).
    wait 2.
    set kuniverse:activevessel to dishProc:part:ship.
}
if shouldPhase(3) and amDish and obt:eccentricity > 0.05 {
    wait 1.
    core:doevent("Close Terminal").
    wait until procCount() = 1.
    core:doevent("Open Terminal").
    wait until ship = kuniverse:activevessel.
    wait 2.
    print "I'm the active vessel!".
    set ship:name to "P3 Dish " + (bodyVesselCount() - 1).
    shipActivateAllEngines().
    changeApAtPe(ringAlt). 
    nodeExecute().
    orbitTunePeriod(ringPeriod, fixingDur).
    waitWarp(time + 300).
    set kuniverse:activevessel to vessel(dispenserName).
}
if shouldPhase(4) {
    kuniverse:quicksaveto("p3_dish_3").
    changePeAtAp(20500 + atmHeightOr0(body)).
    nodeExecute().
    waitWarp(time:seconds + obt:eta:periapsis).
    print "Doing science at " + altitude.
    doUseOnceScience().
    print "Warping to ap to dispose of inter stage".
    waitWarp(time:seconds + obt:eta:apoapsis - 100).
    lock steering to retrograde * r(5, 0, 0).
    wait 5.
    unlock steering.
    stageTo(returnStage).
    print "Waiting for inter stage to deorbit".
    wait 20.
    circleNextExec(apoapsis).
    local travelContext to lexicon(
        "dest", kerbin,
        "altitude", 100000,
        "inclination", 0
    ).
    travelTo(travelContext).
}
if shouldPhase(5) {
    circleAtKerbin().
}
if shouldPhase(6) {
    set kLandKsc:ReturnTanly to 103.
    landKsc().
}

function dishNorm {
    parameter normIndex.
    // These must be gotten while orbiting the destination
    if normIndex = 0 {
        return solarPrimeVector.
    } else if normIndex = 1 {
        return vCrs(solarPrimeVector, unitY).
    } else {
        return unitY.
    }
}

function setStages {
    if amDish {
        set kPhases:phase to 3.
    } else if kPhases:phase < 0 {
        wait 1.
        if body = kerbin {
            set kPhases:startInc to 0.
            set kPhases:stopInc to 2.
        } else if dishCount > 0 {
            set kPhases:startInc to 2.
            set kPhases:stopInc to 2.
        } else {
            set kPhases:startInc to 4.
            set kPhases:stopInc to 6.
        }
    }
}

function bodyVesselCount {
    local tgts to list().
    list targets in tgts.
    local count to 0.
    for t in tgts {
        if t:typename = "Vessel" and t:obt:body = obt:body
            and not vesselIsAsteroid(t) {
            print t:typename + " " + t:name + " " + t:body + " " + t:sizeclass.
            set count to count + 1.
        }
    }
    return count.
}