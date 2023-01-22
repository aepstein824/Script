@LAZYGLOBAL OFF.

runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").

function launchToOrbit {
    ensureHibernate().
    climbInit().
    until climbSuccess() {
        climbLoop().
    }
    climbCleanup().
}