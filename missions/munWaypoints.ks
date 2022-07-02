@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/info.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/moon.ks").
runOncePath("0:phases/waypoints.ks").

local dest to minmus.
local kMunPeLow to kWarpHeights[minmus].
local kMunPeHigh to kMunPeLow * 3.

wait until ship:unpacked.

kuniverse:quicksaveto("mun_wp_launch").
print "Launch to Orbit!".
launchToOrbit().
wait 1.
ensureHibernate().
print "Going to " + dest:name.
doMoonFlyby(dest).
nodeExecute().
waitWarp(time:seconds + 10 * 60).
wait 5.
if not orbit:hasnextpatch() {
    print "Correcting Course".
    doMoonFlyby(dest).
    nodeExecute().
}
waitWarp(time:seconds + orbit:nextpatcheta + 60).
print "Missing the " + dest:name.
refinePe(kMunPeLow, kMunPeHigh).
print "Circling " + dest:name.
circleNextExec(kMunPeLow).
print "Do Waypoints".
doWaypoints().