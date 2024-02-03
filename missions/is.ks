@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:phases/rndv.ks").

local kAimSpd to 7000.
set kPhases:phase to 5.

if shouldPhase(0) {
    set target to cercani.
    stellarTowards(sun, cercani).
}
if shouldPhase(1) {
    stellarWarpTo(cercani).
}
if shouldPhase(2) {
    stellarCorrect().
}
if shouldPhase(3) {
    // set PE, capture circle
}
if shouldPhase(4) {
    stellarTowards(cercani, sun).
}
if shouldPhase(5) {
    stellarWarpTo(sun).
    set target to kerbin.
    stellarCorrect(kerbin).
}

function stellarTravelData {
    parameter spd, origin, dest.
    local distance to (dest:position - origin:position):mag.
    local travelDur to distance / spd.
    local arrivalTime to time + travelDur.
    local otherPos to positionAt(dest, arrivalTime).
    local toOther to (otherPos - origin:position).
    return lex(
        "distance", distance,
        "travelDur", travelDur,
        "arrivalTime", arrivalTime,
        "otherPos", otherPos,
        "toOther", toOther
    ).
}

function stellarTowards {
    parameter origin, dest.
    local spd to kAimSpd.
    local travelData to stellarTravelData(spd, origin, dest).
    print "Travel for " + timeRoundStr(travelData:travelDur).
    escapeWith(spd * travelData:toOther:normalized, 0).
    nodeExecute().
}

function stellarWarpTo {
    parameter dest.
    local spd to kAimSpd.
    local travelData to stellarTravelData(spd, ship, dest).
    waitWarp(time + travelData:travelDur / 2).
}

function stellarCorrect {
    parameter dest.
    local spd to velocity:orbit:mag.
    local travelData to stellarTravelData(spd, ship, dest).
    print "Arrival in " + timeRoundStr(travelData:travelDur).
    local intercept to lambertIntercept(ship, dest,
        time + 360, travelData:travelDur, false).
    add intercept:burnNode.
    nodeExecute().
}
