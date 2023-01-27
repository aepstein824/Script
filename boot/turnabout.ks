@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/orbit").

wait until ship:unpacked.
wait until ship <> kuniverse:activevessel.
orbitDispose().