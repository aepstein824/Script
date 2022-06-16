@LAZYGLOBAL OFF.
clearscreen.
runOncePath("0:maneuvers/node.ks").

wait until ship:unpacked.

kuniverse:quicksaveto("mun_launch").
print "Launch to Orbit!".
launchToOrbit().




function launchToOrbit {
    runOncePath("0:maneuvers/atmClimb.ks").
    set kAtmClimbParams:kLastStage to 2.
    atmClimbInit().
    until atmClimbSuccess() {
        atmClimbLoop().
    }
}


