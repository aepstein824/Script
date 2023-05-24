@LAZYGLOBAL OFF.

runOncePath("0:common/ship").
runOncePath("0:maneuvers/orbit").

wait until ship:unpacked.
wait until ship <> kuniverse:activevessel.
wait until procCount() = 1.
print "Turnabout waiting to deorbit".
orbitDispose().