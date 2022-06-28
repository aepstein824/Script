@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/atmLand.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/moon.ks").
runOncePath("0:phases/waypoints.ks").

local dest to minmus.
local kMunPeLow to kWarpHeights[dest].
local kInterStg to 1.
set kClimb:Turn to 7.
set kClimb:ClimbAp to 76000.
set kPhases:startInc to 1.
set kPhases:stopInc to 1.

wait until ship:unpacked.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("double_mun_launch").
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStg).
}
if shouldPhase(1) {
    print "Plan Intercept".
    local hl to hlIntercept(ship, target).
    add hl:burnNode.
}