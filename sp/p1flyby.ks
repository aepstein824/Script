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
local ind to 1.
local dest to mun.
local height to 0.
local suborb to false.
setDestination().

// Testing
set kPhases:startInc to 0.
set kPhases:stopInc to 6.

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("moon_flyby_launch").
    launchToOrbit().
    wait 3.
}
if shouldPhase(1) {
    local travelContext to lexicon(
        "dest", dest,
        "altitude", height,
        "inclination", 0
    ). 
    travelTo(travelContext).
}
if shouldPhase(2) {
    print "Doing Science".
    doUseOnceScience().
}
if shouldPhase(3) and suborb {
    print "Briefly entering suborbital flight".
    changePeAtAp(-200).
    local dv to nextNode:prograde.
    nodeExecute().
    add node(time:seconds + 60, 0, 0, -dv).
    nodeExecute().
}
if shouldPhase(4) {
    escapePrograde(1.3 * obtMinEscape(body, apoapsis), 0).
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    circleAtKerbin().
}
if shouldPhase(5) {
    landKsc().
}

function setDestination {
    if ind = 0 or ind = 2 {
        set dest to mun.
    } else {
        set dest to minmus.
    }
    if ind >= 2 {
        set height to 20000.
        set suborb to true.
    } else {
        set height to 1000000. 
        set suborb to false.
    }
}

