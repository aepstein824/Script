@LAZYGLOBAL OFF.
clearscreen.
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/lambert.ks").

local kMunPeLow to 12000.
local kMunPeHigh to 40000.
local kKerbPark to 75000.

wait until ship:unpacked.

// kuniverse:quicksaveto("mun_launch").
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
print "Perform High Science".
wait 1.
doScience().
waitWarp(time:seconds + orbit:eta:periapsis).
dontEscape().
print "Perform Low Science".
wait 5.
doScience().
waitWarp(time:seconds + orbit:nextpatcheta + 60).
print "Prepairing for Reentry".
circleAtKerbin().
landKsc().


function launchToOrbit {
    runOncePath("0:maneuvers/atmClimb.ks").
    set kAtmClimbParams:kLastStage to 2.
    atmClimbInit().
    until atmClimbSuccess() {
        atmClimbLoop().
    }
    lock throttle to 0.
    kuniverse:timewarp:cancelwarp().
    set kuniverse:timewarp:mode to "RAILS".
}

function planMunFlyby {
    local best to Lexicon().
    set best["burnVec"] to V(10000,0,0).
    for i in range(1, 15) {
        for j in list(6, 8, 10) {
            local startTime to time + i * 2 * 60.
            local flightDuration to j * 60 * 60.
            local results to lambert(ship, mun, startTime, 
                flightDuration, false).

            if results["ok"] {
                // print "Found orbit with dV " + results["burnVec"]:mag.
                if results["burnVec"]:mag < best["burnVec"]:mag {
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

function doScience {
    local barometer to ship:partsdubbed("sensorBarometer")[0].
    local thermometer to ship:partsdubbed("sensorThermometer")[0].
    local goos to ship:partsdubbed("gooExperiment").
    local goo to goos[0].
    if goo:getmodule("ModuleScienceExperiment"):inoperable() {
        set goo to goos[1].
    }

    barometer:getmodule("ModuleScienceExperiment"):deploy().
    thermometer:getmodule("ModuleScienceExperiment"):deploy().
    goo:getmodule("ModuleScienceExperiment"):deploy().

    wait 5.

    local eruPart to ship:partsdubbedpattern("Experiment Return")[0].
    local eru to eruPart:getmodule("ModuleScienceContainer").
    until eru:hasevent("container: collect all") {
        wait 0.
    }
    eru:doevent("container: collect all").

    
    wait 1.
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
        changeAp(kKerbPark).
    } else {
        changePe(kKerbPark).
    }
    nodeExecute().
    circleAtPe().
    nodeExecute().
}

function landKsc {
    runPath("0:maneuvers/atmLand.ks").

    atmLandInit().
    until atmLandSuccess() {
        atmLandLoop().
    }
}