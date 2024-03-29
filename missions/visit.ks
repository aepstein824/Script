@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/travel.ks").

set kPhases:startInc to 1.
set kPhases:stopInc to 1.

local dest to vessel("Vexatious").
local kInterStg to 1.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("visit_" + dest:name + "_launch").
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStg).
}
if shouldPhase(1) {
    print "Rndv with " + dest:name.
    setTargetTo(dest:name).
    travelTo(lexicon("dest", dest)).
}
if shouldPhase(2) {
    print "Docking with " + target:name.
    rcsApproach().
}