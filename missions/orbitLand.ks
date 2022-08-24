@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

local kWaitTime to 40 * 6 * 60 * 60.

runOncePath("0:common/phasing.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/landKsc.ks").

set kPhases:startInc to 0.
set kPhases:stopInc to 0.

set kClimb:Turn to 2.
set kClimb:TLimAlt to 20000.
set kClimb:ClimbAp to 100000.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("orbit_land_launch").
    launchToOrbit().
    panels on.
    wait 2.
}
if shouldPhase(1) {
    circleNextExec(80000).
    lock throttle to 0.
    print "Wait in orbit!".
    wait 5.
    waitWarp(time:seconds + kWaitTime).
} 
if shouldPhase(2) {
    print "Land at Ksc!".
    panels off.
    landKsc().
}




