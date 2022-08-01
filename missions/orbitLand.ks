@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

local kWaitTime to 40 * 6 * 60 * 60.

runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/landKsc.ks").

print "Launch to Orbit!".
kuniverse:quicksaveto("orbit_land_launch").
launchToOrbit().
panels on.
wait 2.
circleNextExec(80000).
lock throttle to 0.
print "Wait in orbit!".
wait 5.
waitWarp(time:seconds + kWaitTime).
print "Land at Ksc!".
panels off.
landKsc().





