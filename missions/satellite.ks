@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/info.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/launchToOrbit.ks").

set kClimb:Turn to 5.
set kClimb:ClimbA to 1.4.
set kClimb:ClimbAp to 75000.
set kClimb:Heading to 90.
set kClimb:Roll to 0.
set kClimb:TLimAlt to 6000.
set kPhases:startInc to 2.
set kPhases:stopInc to 2.
local kCarrierPark to 1200000.
local kApDir to (v(0, -1, 0) + solarPrimeVector):normalized.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("satellite_launch").
    ensureHibernate().
    launchToOrbit().
    wait 5.
    ag10 on.
}
if shouldPhase(1) {
    circleNextExec(kCarrierPark).
}
if shouldPhase(2) {
    sat100orbit(kApDir).
}

function sat100sun {
    print "Escape Retrograde".
    escapeWith(-5000, 0).
    local nn to nextNode.
    set nn:prograde to ship:deltav:current - 300.
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