@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/waypoints.ks").

local kMunPeLow to 12000.
local kMunPeHigh to 40000.
local kKerbPark to 75000.

wait until ship:unpacked.

kuniverse:quicksaveto("mun_launch").
print "Launch to Orbit!".
launchToOrbit().
ensureHibernate().
print "Planning Mun Flyby".
planMunFlyby().
print "Heading off to Mun".
nodeExecute().
waitWarp(time:seconds + 10 * 60).
print "Correcting Course".
planMunFlyby().
nodeExecute().
waitWarp(time:seconds + orbit:nextpatcheta + 60).
print "Missing the Mun".
refinePe(kMunPeLow, kMunPeHigh).
print "Circling Mun".
changeApAtPe(kMunPeLow).
nodeExecute().
changeApAtPe(kMunPeLow).
nodeExecute().
doWaypoints().
wait 2.
escapeRetro().
nodeExecute().
waitWarp(time:seconds + orbit:nextpatcheta + 60).
circleAtKerbin().
landKsc().


function launchToOrbit {
    runOncePath("0:maneuvers/atmClimb.ks").
    set kAtmClimbParams:kLastStage to 2.
    atmClimbInit().
    until atmClimbSuccess() {
        atmClimbLoop().
    }
    atmClimbCleanup().
}

function planMunFlyby {
    local best to Lexicon().
    set best:totalV to 1000000.
    for i in range(1, 15) {
        for j in list(7, 8, 9) {
            local startTime to time + i * 2 * 60.
            local flightDuration to j * 60 * 60.
            local results to lambert(ship, mun, V(-2 * mun:radius, 0, 0),
                startTime, flightDuration, false).

            if results:ok {
                set results:totalV to results:burnVec:mag. 
                // set results:totalV to results:totalV + results:matchVec:mag.
                print "Found orbit with dV " + results["burnVec"]:mag + " total " 
                    + results:totalV.
                if results:totalV < best:totalV {
                    set best to results.
                }
            }
        }
    }
    local nd to best["burnNode"].
    add nd.
    for i in range(30) {
        if (nd:obt:nextpatch():periapsis < 0) {
            set nd:prograde to nd:prograde - 0.5.
        } else if (nd:obt:nextpatch():periapsis < kMunPeLow) {
            set nd:prograde to nd:prograde - 0.1.
        } else {
            break.
        }
    }
}

function ensureHibernate {
    for part in ship:parts {
        for modName in part:modules {
            if modName:contains("command") {
                local module to part:getmodule(modName).
                if module:hasField("Hibernate in Warp") {
                    module:setfield("Hibernate in Warp", "Auto").
                }
            }
        }
    }
}

function refinePe {
    parameter low, high.
    add node(time, 1, 0, 1).
    local proAndOut to nextnode:deltav:normalized.
    if ship:periapsis < low {
        lock steering to proAndOut.
    } else if ship:periapsis > high {
        lock steering to -1 * proAndOut.
    } 
    wait 3.
    until ship:periapsis > low and ship:periapsis < high {
        lock throttle to 0.1.
        nodeStage().
        wait 0.
    }
    lock throttle to 0.
    remove nextNode.
    wait 1.
    return.
}

function dontEscape {
    print obt:nextpatch():transition + " " + obt:nextpatch:apoapsis.
    if obt:nextpatch():transition <> "FINAL"
        or (obt:nextpatch():apoapsis > 0.5 * minmus:altitude) {
            print "ESCAPING?!".
            add node(time + 60, 0, 0, -50).
            wait 0.
            nodeExecute().
    } else {
        print "Just fine actually " + obt:nextpatch():transition <> "FINAL".
    }
}

function circleAtKerbin {
    if obt:transition <> "FINAL" {
        print "Avoiding escape!".
        lock steering to ship:retrograde.
        wait 1.
        lock throttle to 1.
        wait until obt:transition = "FINAL".
        lock throttle to 0.
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
    runPath("0:maneuvers/atmLand.ks").

    atmLandInit().
    until atmLandSuccess() {
        atmLandLoop().
    }
}