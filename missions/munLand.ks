@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/atmLand.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/moon.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/waypoints.ks").

local dest to minmus.
local kMunPeLow to kWarpHeights[dest].
local kMunPeHigh to kMunPeLow * 3.
local kInterStg to 2.
local kLanderStg to 2.
set kClimb:Turn to 5.
set kClimb:ClimbAp to 80000.
set kPhases:startInc to 8.
set kPhases:stopInc to 8.
local lz to latlng(-67, 72).

wait until ship:unpacked.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("mun_land_launch").
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStg).
}
if shouldPhase(1) {
    doMoonFlyby(dest).
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}
if shouldPhase(2) {
    print "Missing the " + dest:name.
    refinePe(kMunPeLow, kMunPeHigh).
}
if shouldPhase(3) {
    print "Circling " + dest:name.
    circleNextExec(kMunPeLow).
}
if shouldPhase(4) {
    print "Landing".
    lights on.
    vacDescendToward(lz).
    print ship:geoposition.
    stageTo(kLanderStg).
    vacLand().
    print ship:geoposition.
}
if shouldPhase(5) {
    verticalLeapTo(100).
    wait until ship:velocity:surface:mag < 2.
    hopBestTo(latlng(lz):altitudeposition(100)).
    suicideBurn(100).
    coast(5).
    doScience().
}
if shouldPhase(6) {
    lights off.
    print "Leaving " + dest:name.
    vacClimb().
    circleNextExec(kMunPeLow).
    escapeWith(-150, 0).
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    circleAtKerbin().
}
if shouldPhase(7) {
    print "Rndv with lab".
    local hl to hohmannIntercept(ship:obt, target:obt).
    add node(time + hl:when, 0, 0, hl:vd).
    nodeExecute().
    waitWarp(time:seconds + hl:duration - 60).
    ballistic().
    rcsNeutralize().
}
if shouldPhase(8) {
    if (target:position:mag > kRndvParams:floatDist) {
        ballistic().
        rcsNeutralize().
    }
    rcsApproach().
}
if shouldPhase(9) {
    landKsc().
}

function vacDescendToward {
    parameter wGeo.
   
    matchGeoPlane(wGeo).

    local wPos to wGeo:position - body:position.
    local pePos to shipPAtPe().
    local wTanly to vectorAngleAround(pePos, shipNorm(), wPos).
    local landAngle to 20.
    local landTanly to mod(wTanly - landAngle + 360, 360).
    print "wTanly = " + wTanly.
    print "landTanly = " + landTanly.
    local landTime to timeBetweenTanlies(obt:trueanomaly, landTanly, obt) + time:seconds.
    local res to landingOptimizer(ship, wGeo:position, landTime, 0, true).
    add res["burnNode"].
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