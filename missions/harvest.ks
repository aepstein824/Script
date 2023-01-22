@LAZYGLOBAL OFF.

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
clearAll().

set kPhases:startInc to 1.
set kPhases:stopInc to 2.

// NOTE must be in body's orbit
local lz to latlng(19.5, -174.9).
local home to vessel("hive").

if shouldPhase(0) {
    print "Landing".
    vacDescendToward(lz).
    lights on.
    vacLand().
    print "Landed at " + ship:geoposition.
    lights off.
}
if shouldPhase(1) {
    setTargetTo(home).

    lights off.
    print "Lifting off " + body:name.
    local alti to 1.1 * home:altitude.
    waitForTargetPlane(home).
    vacClimb(alti, launchHeading()).
    circleNextExec(alti).
}
if shouldPhase(2) {
    print "Rndv with " + home:name.

    local travelCtx to lexicon("dest", home).
    travelTo(travelCtx).

    rcsApproach().
}