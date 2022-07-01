@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

local kWaitTime to 40 * 6 * 60 * 60.

runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/landKsc.ks").

print "Launch to Orbit!".
kuniverse:quicksaveto("orbit_land_launch").
launchToOrbit().
lock throttle to 0.
print "Wait in orbit!".
wait 5.
waitWarp(time:seconds + kWaitTime).
print "Land at Ksc!".
landKsc().





