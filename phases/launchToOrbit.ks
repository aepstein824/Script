@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/atmClimb.ks").
set kAtmClimbParams:kLastStage to 1.
local circleAlt to 75000.

atmClimbInit().
until atmClimbSuccess() {
    atmClimbLoop().
}
atmClimbCleanup().
wait 2.
changeAp(circleAlt).
nodeExecute().
changePe(circleAlt).
nodeExecute().


