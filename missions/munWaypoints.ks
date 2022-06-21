@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/atmLand.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/moon.ks").
runOncePath("0:phases/waypoints.ks").

local kMunPeLow to 12000.
local kMunPeHigh to 40000.

wait until ship:unpacked.

kuniverse:quicksaveto("mun_wp_launch").
print "Launch to Orbit!".
launchToOrbit().
wait 1.
ensureHibernate().
print "Going to Mun".
planMunFlyby().
nodeExecute().
waitWarp(time:seconds + 10 * 60).
wait 5.
if not orbit:hasnextpatch() {
    print "Correcting Course".
    planMunFlyby().
    nodeExecute().
}
waitWarp(time:seconds + orbit:nextpatcheta + 60).
print "Missing the Mun".
refinePe(kMunPeLow, kMunPeHigh).
print "Circling Mun".
circleNextExec(kMunPeLow).
print "Do Waypoints".
doWaypoints().