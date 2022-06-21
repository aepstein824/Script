@LAZYGLOBAL OFF.

runPath("0:maneuvers/atmLand.ks").

local kKerbPark to 75000.

function circleAtKerbin {
    if obt:transition <> "FINAL" {
        print "Avoiding escape!".
        lock steering to ship:retrograde.
        wait 1.
        lock throttle to 1.
        wait until obt:transition = "FINAL".
        lock throttle to 0.
        wait 5.
    }
    if obt:eta:periapsis < obt:eta:apoapsis {
        changeApAtPe(kKerbPark).
    } else {
        changePeAtAp(kKerbPark).
    }
    nodeExecute().
    changeApAtPe(kKerbPark).
    local dvBudget to ship:deltav:current - 200.
    print dvBudget.
    if nextnode:prograde < 0 {
        set nextnode:prograde to max(nextnode:prograde, -dvBudget).
    } else {
        set nextnode:prograde to min(nextnode:prograde, dvBudget).
    }
    nodeExecute().
}

function landKsc {
    landingBurn().
    atmLandInit().
    until atmLandSuccess() {
        atmLandLoop().
    }
}