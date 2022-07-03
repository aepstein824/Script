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

wait until ship:unpacked.

set kPhases:startInc to 2.
set kPhases:stopInc to 2.

set kClimb:Turn to 3.
set kClimb:TLimAlt to 15000.
set kClimb:ClimbAp to 75000.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("asteroid_launch").
    ensureHibernate().
    targetAsteroid().
    set kClimb:Heading to launchHeading().
    launchToOrbit().
    ag10 off. ag10 on.
}
if shouldPhase(1) {
    print "Catch " + target:name.
    local hl to hlIntercept(ship, target).
    add hl:burnNode.
    nodeExecute().
}
if shouldPhase(2) {
    local tClose to closestApproach(ship, target).
    print (tClose - time:seconds) / 3600.
    local il to informedLambert(ship, target, 1.5* (tClose - time:seconds)).
    add il:burnNode.
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

function bestNorm {
    local tPos to target:obt:position - body:position.
    local tVel to target:obt:velocity:orbit.
    local tNorm to vCrs(tVel, tPos).
    local ourPos to -body:position.
    local inPlane to removeComp(tNorm, ourPos):normalized.
    return inPlane.
}

function launchHeading {
    local norm to bestNorm().
    local pos to -body:position.
    local launchDir to vCrs(pos, norm).
    local headingAngle to vectorAngleAround(launchDir, pos, v(0, 1, 0)).
    return headingAngle.
}