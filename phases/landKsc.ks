@LAZYGLOBAL OFF.

runPath("0:maneuvers/landAtm.ks").

local kKerbPark to 75000.
local kLandingBudget to 200.

function circleAtKerbin {
    if obt:transition = "ESCAPE" {
        print "Avoiding escape!".
        lock steering to ship:retrograde.
        wait 1.
        lock throttle to 1.
        wait until obt:transition = "FINAL".
        lock throttle to 0.
        wait 5.
    }

    matchPlanesAndSemi(V(0, 1, 0), kKerbPark).
    if nextNodeOverBudget(kLandingBudget) {
        remove nextNode. 
        changePeAtAp(kKerbPark).
    }
    nodeExecute().
    wait 1.
    changeApAtPe(kKerbPark).
    local dvBudget to ship:deltav:current - kLandingBudget.
    if nextnode:prograde < 0 {
        set nextnode:prograde to max(nextnode:prograde, -dvBudget).
    } else {
        set nextnode:prograde to min(nextnode:prograde, dvBudget).
    }
    nodeExecute().
}

function landKsc {
    planLandingBurn().
    nodeExecute().
    print ship:geoposition.
    landFromDeorbit().
    print ship:geoposition.
}