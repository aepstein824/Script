@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:maneuvers/atmLand.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/moon.ks").
runOncePath("0:phases/waypoints.ks").

local kMunPeLow to 12000.
local kMunPeHigh to 40000.
set kClimb:Turn to 8.
set kClimb:ClimbAp to 82000.
set kClimb:burnHeight to 78500.

wait until ship:unpacked.

kuniverse:quicksaveto("mun_land_probe_launch").
ensureHibernate().
print "Launch to Orbit!".
launchToOrbit().
wait 1.
planMunFlyby().
nodeExecute().
if not orbit:hasnextpatch() {
    print "Correcting Course".
    waitWarp(time:seconds + 10 * 60).
    planMunFlyby().
    nodeExecute().
}
waitWarp(time:seconds + orbit:nextpatcheta + 60).
print "Missing the Mun".
refinePe(kMunPeLow, kMunPeHigh).
print "Circling Mun".
circleNextExec(kMunPeLow).
wait 2.
print "Landing".
vacLand().
doScience().
print "Leaving Mun".
vacClimb().
circleNextExec(kMunPeLow).
escapeRetro().
nodeExecute().
waitWarp(time:seconds + orbit:nextpatcheta + 60).
circleAtKerbin().
landKsc().

function vacLand {
    add node(time:seconds + 60, 0, 0, -300).
    nodeExecute().
    legs on.
    suicideBurn(150).
    coast(5).
}

function vacClimb {
    verticalLeapTo(100).
    lock steering to heading(90, 45, 0).
    lock throttle to 1.
    until apoapsis > kMunPeLow {
        nodeStage().
        wait 0.
    }
    lock throttle to 0.
}