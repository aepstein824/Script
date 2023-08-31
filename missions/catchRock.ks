@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/rndv.ks").

wait until ship:unpacked.

set kPhases:startInc to 5.
set kPhases:stopInc to 5.

set kClimb:Turn to 4.
set kClimb:TLimAlt to 15000.
set kClimb:ClimbAp to 75000.
local kInterStg to 0.
local kAsteroidStorage to 120000.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("asteroid_launch").
    ensureHibernate().
    set kClimb:Heading to launchHeading().
    launchToOrbit().
    ag10 off. ag10 on.
    stageTo(kInterStg).
}
if shouldPhase(1) {
    print "Catch " + target:name.
    kuniverse:quicksaveto("vampire_hunting").
    local hl to hlIntercept(ship, target).
    add hl:burnNode.
    nodeExecute().
    for i in range(1) {
        print "Refining Intercept " + i.
        local tClose to closestApproach(ship, target).
        local flightDuration to tClose - time:seconds.
        local il to courseCorrect(target, flightDuration).
        nodeExecute().
    }

}
if shouldPhase(2) {
    local tClose to closestApproach(ship, target).
    waitWarp(tClose - 10 * 60).
    doubleBallisticRcs().
}
if shouldPhase(3) {
    // rcsApproach(). // unreliable
    kuniverse:pause().
}
if shouldPhase(4) {
    mineAsteroid().
}
if shouldPhase(5) {
    // nodeExecute(). // exercise for the miner.
    // changeApAtPe(kerbin:soiradius * 0.9).
    // nodeExecute().
    // matchPlanesAndSemi(normOf(mun), kAsteroidStorage).
    // nodeExecute().
    circleNextExec(kAsteroidStorage).
}
if shouldPhase(6) {
}

function targetAsteroid {
    local astSizes to list("A", "B", "C", "D", "E").
    local candidates to list().
    list targets in candidates.
    for c in candidates {
        if astSizes:find(c:sizeclass) <> -1 
            and c:body = kerbin {
                set target to c.
                break.
        }
    }
}

