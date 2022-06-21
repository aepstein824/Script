@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").

function launchToOrbit {
    climbInit().
    until climbSuccess() {
        climbLoop().
    }
    climbCleanup().
}