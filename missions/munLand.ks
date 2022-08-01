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
runOncePath("0:phases/travel.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/waypoints.ks").

set kPhases:startInc to 4.
set kPhases:stopInc to 4.

local dest to minmus.
local kMunPeLow to kWarpHeights[dest].
local kMunPeHigh to kMunPeLow * 3.
local kInterStg to 0.
local kLanderStg to 0.
set kClimb:Turn to 5.
set kClimb:ClimbAp to 80000.
local lz to latlng(-89, -113).

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
    local travelContext to lexicon(
        "dest", dest,
        "altitude", kWarpHeights[dest],
        "inclination", 0
    ). 
    travelTo(travelContext).
}
if shouldPhase(2) {
    print "Circling " + dest:name.
    circleNextExec(kMunPeLow).
    doAG13To45Science().
}
if shouldPhase(3) {
    print "Landing".
    lights on.
    vacDescendToward(lz).
    stageTo(kLanderStg).
    vacLand().
    print "Landed at " + ship:geoposition.
}
if shouldPhase(4) {
    verticalLeapTo(100).
    wait until ship:velocity:surface:mag < 2.
    hopBestTo(lz:altitudeposition(100)).
    suicideBurn(100).
    coast(5).
}
if shouldPhase(5) {
    lights off.
    print "Leaving " + dest:name.
    vacClimb(kMunPeLow).
    circleNextExec(kMunPeLow).
    // escapeWith(-150, 0).
    // nodeExecute().
    // waitWarp(time:seconds + orbit:nextpatcheta + 60).
    // circleAtKerbin().
}
if shouldPhase(6) {
    print "Rndv with lab".
    setTargetTo("KLab").

    local hl to hlIntercept(ship, target).
    add hl:burnNode.

    nodeRcs().
    waitWarp(closestApproach()).
    doubleBallisticRcs().
}
if shouldPhase(7) {
    print "Dock with lab".
    setTargetTo("KLab").
    rcsApproach().
}
if shouldPhase(8) {
    landKsc().
}

