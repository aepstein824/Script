@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

print "Launch to Orbit!".
runOncePath("0:phases/launchToOrbit.ks").

print "Wait in orbit!".
lock throttle to 0.
wait 3.
kuniverse:timewarp:warpto(time:seconds + 60 * 60).
wait 60 * 60.
print "Land at Ksc!".
runOncePath("0:phases/landKsc.ks").





