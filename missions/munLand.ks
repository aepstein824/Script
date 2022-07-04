@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
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
local lz to latlng(14, -45).

wait until ship:unpacked.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("mun_land_launch").
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStg).
    doAG13To45Science().
}
if shouldPhase(1) {
    doMoonFlyby(dest).
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    doAG13To45Science().
}
if shouldPhase(2) {
    print "Missing the " + dest:name.
    refinePe(kMunPeLow, kMunPeHigh).
}
if shouldPhase(3) {
    print "Circling " + dest:name.
    circleNextExec(kMunPeLow).
    doAG13To45Science().
}
if shouldPhase(4) {
    print "Landing".
    lights on.
    vacDescendToward(lz).
    stageTo(kLanderStg).
    vacLand().
    doAG1To45Science().
    print ship:geoposition.
}
if shouldPhase(5) {
    verticalLeapTo(100).
    wait until ship:velocity:surface:mag < 2.
    hopBestTo(lz:altitudeposition(100)).
    suicideBurn(100).
    coast(5).
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
    setTargetTo("KLab").

    local hl to hlIntercept(ship, target).
    add hl:burnNode.

    nodeRcs().
    waitWarp(time:seconds + hl:duration).
    ballistic().
    rcsNeutralize().
}
if shouldPhase(8) {
    print "Dock with lab".
    setTargetTo("KLab").
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

    local norm to shipNorm().
    local wPos to wGeo:position - body:position.
    local pePos to shipPAtPe().
    local wTanly to vectorAngleAround(pePos, norm, wPos).
    local landAngle to 20.
    local landTanly to mod(wTanly - landAngle + 360, 360).
    print "wTanly = " + wTanly.
    print "landTanly = " + landTanly.
    local landDur to timeBetweenTanlies(obt:trueanomaly, landTanly, obt).

    local mm to 360 / obt:period.
    print "mm " + mm.
    // bodyMm is right handed
    local bodyMm to -body:angularvel:y * constant:radtodeg.
    print "bdmm " + bodyMm.
    // positive norm and bodymm mean body is moving in same direction, land later
    local timeFactor to (mm + bodyMm * norm:y) / mm.
    print "timeFactor " + timeFactor.
    set landDur to landDur * timeFactor.
    local p2 to rotateVecAround(wPos, v(0, 1, 0), bodyMm * landDur).
    
    local landTime to time + landDur.
    local res to lambertLanding(ship, p2, landTime).
    add res:burnNode.
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
    wait until altitude > 3100.
}