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

// Mission parameters
local dest to minmus.
local kMoonPeLow to opsScienceHeight(dest) + 2000.
local kInterStg to 2.
local kLanderStg to 2.
local kReturnStg to 1.
local lz to dest:geopositionlatlng(69, 69).

// Testing
set kPhases:startInc to 0.
set kPhases:stopInc to 6.
// set kPhases:phase to 2.

// Launch
set kClimb:Turn to 3.5.

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("moon_land_launch").
    launchToOrbit().
    stageTo(kInterStg).
    wait 3.
}
if shouldPhase(1) {
    local travelContext to lexicon(
        "dest", dest,
        "altitude", kMoonPeLow,
        "inclination", 90
    ). 
    travelTo(travelContext).
}
if shouldPhase(2) {
    print "Landing".
    lights on.
    vacDescendToward(lz).
    stageTo(kLanderStg).
    vacLandGeo(lz).
    print "Landed at " + ship:geoposition.
}
if shouldPhase(3) {
    print "Doing Science".
    doUseOnceScience().
}
if shouldPhase(4) {
    lights off.
    print "Leaving " + dest:name.
    vacClimb(kMoonPeLow).
    stageTo(kReturnStg).
    circleNextExec(kMoonPeLow).
}
if shouldPhase(5) {
    escapePrograde(1.3 * obtMinEscape(body, apoapsis), 20).
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    circleAtKerbin().
}
if shouldPhase(6) {
    landKsc().
}

