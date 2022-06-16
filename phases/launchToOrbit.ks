@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

runOncePath("0:maneuvers/atmClimb.ks").
set kAtmClimbParams:kLastStage to 2.

atmClimbInit().
until atmClimbSuccess() {
    atmClimbLoop().
}


