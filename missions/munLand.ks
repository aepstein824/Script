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

set kPhases:startInc to 0.
set kPhases:stopInc to 6.

local dest to mun.
local kMoonPeLow to kWarpHeights[dest].
local kInterStg to 2.
local kLanderStg to 2.
set kClimb:Turn to 5.
set kClimb:ClimbAp to 80000.

// TODO only in body's orbit
local lz to latlng(0, 0).

wait until ship:unpacked.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("mun_land_launch").
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStg).
}
if shouldPhase(1) {
    local travelContext to lexicon(
        "dest", dest,
        "inclination", 0
    ). 
    travelTo(travelContext).
}
if shouldPhase(2) {
    print "Circling " + dest:name.
}
if shouldPhase(3) {
    print "Landing".
    lights on.
    vacDescendToward(lz).
    stageTo(kLanderStg).
    vacLand().
    print " Landed at " + ship:geoposition.
}
if false and shouldPhase(4) {
    verticalLeapTo(200).
    wait until abs(ship:velocity:surface:y) < 2.
    hopBestTo(lz:altitudeposition(100)).
    suicideBurn(100).
    coast(5).
}
if shouldPhase(5) {
    lights off.
    print "Leaving " + dest:name.
    vacClimb(kMoonPeLow).
    circleNextExec(kMoonPeLow).
    // escapeWith(-150, 0).
    // nodeExecute().
    // waitWarp(time:seconds + orbit:nextpatcheta + 60).
    // circleAtKerbin().
}
if shouldPhase(6) {
    print "Rndv with lab".
    setTargetTo("KLab").

    local travelCtx to lexicon("dest", target).
    travelTo(travelCtx).
}
if shouldPhase(7) {
    print "Dock with lab".
    setTargetTo("KLab").
    rcsApproach().
}
if shouldPhase(8) {
    landKsc().
}

