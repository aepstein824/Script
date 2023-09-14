@LAZYGLOBAL OFF.

runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").

function launchToOrbit {
    ensureHibernate().

    if hasTarget and shipIsLandOrSplash() {
        waitForTargetPlane(target).
        set kClimb:Heading to launchHeading().
        print " Launching with heading " + round(kClimb:Heading, 2).
    }

    climbInit().
    until climbSuccess() {
        climbLoop().
    }
    climbCleanup().
}