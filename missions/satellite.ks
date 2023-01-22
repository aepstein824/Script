@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/info.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/travel.ks").

set kPhases:startInc to 3.
set kPhases:stopInc to 3.

set kClimb:Turn to 2.
set kClimb:ClimbA to 1.3.
set kClimb:ClimbAp to 90000.
set kClimb:Heading to 90.
set kClimb:Roll to 0.
set kClimb:TLimAlt to 14000.
local shouldPark to true.
local kCarrierPark to 120000.
local kInterStage to 0.
local dest to minmus.

// TODO only call this when in the correct body's orbit
local kApDir to sat100dirs()[3].

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("satellite_" + dest:name).
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStage).
    // lifter is yeeting itself back onto the surface 
    lock throttle to 0.2.
    wait 1.
    lock throttle to 0.
    wait 5.
    ag10 on.
}
if shouldPhase(1) and shouldPark {
    circleNextExec(kCarrierPark).
}
if shouldPhase(2) {
    // sat100sun().
    set target to dest.
    local travelContext to lexicon(
        "dest", dest,
        "altitude", polarScannerAltitude(dest),
        "inclination", 90
    ).
    travelTo(travelContext).
}
if shouldPhase(3) {
    sat100orbit(kApDir).
}

function sat100sun {
    print "Escape Retrograde".
    escapeWith(-5000, 0).
    set nextnode:prograde to ship:deltav:current - 300.
    nodeExecute().
}

function sat100orbit {
    parameter dir.
    local norm to removeComp(shipNorm(), dir):normalized.
    print "Orbit " + body:name + " toward " + dir. 
    matchPlanesAndSemi(norm, kWarpHeights[body]).
    nodeExecute().
    circleNextExec(kWarpHeights[body]).
    wait 1.
    local opTanly to posToTanly(-body:radius * dir + body:position, obt).
    local atOp to timeBetweenTanlies(obt:trueanomaly, opTanly, obt) + time.
    local r1 to (obt:position - body:position):mag.
    local r2 to 0.85 * body:soiradius.
    local burnV to circleToSemiV(r1, r2, body:mu).
    add node(atOp, 0, 0, burnV).
    nodeExecute().
}

function sat100dirs {
    return list(
        (v(0, 1, 0) + solarPrimeVector):normalized,
        (v(0, 1, 0) - solarPrimeVector):normalized,
        (v(0, -1, 0) + solarPrimeVector):normalized,
        (v(0, -1, 0) - solarPrimeVector):normalized
    ).
}
