@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:maneuvers/atmLand.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/moon.ks").
runOncePath("0:phases/waypoints.ks").

local dest to mun.
local kMunPeLow to kWarpHeights[dest].
local kMunPeHigh to kMunPeLow * 3.
local kInterStg to 2.
local kLanderStg to 2.
set kClimb:Turn to 5.
set kClimb:ClimbAp to 75000.
local phase to 5.
local auto to true.

wait until ship:unpacked.

if phase = 0 or auto {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("mun_land_probe_launch").
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStg).
}
if phase = 1 or auto {
    print "Go to " + dest:name.
    planMunFlyby().
    nodeExecute().
    if not orbit:hasnextpatch() {
        print "Correcting Course".
        waitWarp(time:seconds + 10 * 60).
        planMunFlyby().
        nodeExecute().
    }
}
if phase = 2 or auto {
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    print "Missing the " + dest:name.
    refinePe(kMunPeLow, kMunPeHigh).
}
if phase = 3 or auto {
    print "Circling " + dest:name.
    circleNextExec(kMunPeLow).
}
if phase = 4 or auto {
    print "Landing".
    lights on.
    vacDescendToward(latlng(-20,-23)).
    print ship:geoposition.
    stageTo(kLanderStg).
    vacLand().
    doScience().
    print ship:geoposition.
}
if phase = 5 or auto {
    lights off.
    print "Leaving " + dest:name.
    vacClimb().
    circleNextExec(kMunPeLow).
    escapeRetro().
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    circleAtKerbin().
    landKsc().
}

function vacDescendToward {
    parameter wGeo.
   
    matchGeoPlane(wGeo).

    local pePos to shipPAtPe().
    local wTanly to vectorAngleAround(pePos, shipNorm(), 
        wGeo:position - body:position).
    local landAngle to 6.5.
    local landTanly to mod(wTanly - landAngle + 360, 360).
    print "wTanly = " + wTanly.
    print "landTanly = " + landTanly.
    local landTime to timeBetweenTanlies(obt:trueanomaly, landTanly, obt).
    add node(time:seconds + landTime, 0, 0, -300).
    nodeExecute().
}

function vacLand {
    legs on.
    suicideBurn(600).
    suicideBurn(100).
    coast(5).
}

function vacClimb {
    verticalLeapTo(100).
    lock steering to heading(90, 45, 0).
    lock throttle to 1.
    until apoapsis > kMunPeLow {
        nodeStage().
        wait 0.
    }
    lock throttle to 0.
}