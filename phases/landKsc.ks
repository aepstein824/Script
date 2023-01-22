@LAZYGLOBAL OFF.

runPath("0:common/control.ks").
runPath("0:maneuvers/landAtm.ks").

local kKerbPark to 75000.
local kLandingBudget to 200.

function preventEscape {
    controlLock().
    if obt:transition = "ESCAPE" {
        print "Avoiding escape!".
        set controlSteer to ship:retrograde.
        wait 1.
        set controlThrot to 1.
        wait until obt:transition = "FINAL".
        set controlThrot to 0.
        wait 1.
    }
    controlUnlock().
}

function circleAtKerbin {

    preventEscape().

    changePeAtAp(kKerbPark).
    nodeExecute().

    changeApAtPe(kKerbPark).
    local dvBudget to ship:deltav:current - kLandingBudget.
    set nextNode:prograde to clampAbs(nextNode:prograde, dvBudget).
    nodeExecute().
}

function landKsc {
    planLandingBurn().
    nodeExecute().
    landFromDeorbit().
}