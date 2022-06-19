@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

runOncePath("0:maneuvers/atmClimb.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").

set kAtmClimbParams:kLastStage to 1.
local circleAlt to 75000.

atmClimbInit().
until atmClimbSuccess() {
    atmClimbLoop().
}
atmClimbCleanup().
wait 2.
changeApAtPe(circleAlt).
nodeExecute().
changePeAtAp(circleAlt).
nodeExecute().


