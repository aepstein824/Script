@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/landAtm.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/travel.ks").
runOncePath("0:phases/waypoints.ks").

set kClimb:Turn to 7.
set kClimb:ClimbAp to 76000.
set kPhases:startInc to 3.
set kPhases:stopInc to 5.

wait until ship:unpacked.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("double_mun_launch").
    ensureHibernate().
    launchToOrbit().
}
if shouldPhase(1) {
    print "Go to Mun".
    travelTo(lexicon("dest", mun, "altitude", 80000)).
}
if shouldPhase(2) {
    print "Go to Minmus".
    travelTo(lexicon("dest", kerbin)).
    travelTo(lexicon("dest", minmus, "altitude", 25000)).
}
if shouldPhase(3) {
    print "Escape Minmus".
    travelTo(lexicon("dest", kerbin)).
}
if shouldPhase(4) {
    circleAtKerbin().
}
if shouldPhase(5) {
    landKsc().
}