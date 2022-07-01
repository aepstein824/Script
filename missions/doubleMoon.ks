@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/landAtm.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/moon.ks").
runOncePath("0:phases/waypoints.ks").

local first to mun.
local kMunLow to 80000.
local kMinmusLow to 28000.
local kCircleHigh to 200000.
local kInterStg to 2.
set kClimb:Turn to 7.
set kClimb:ClimbAp to 76000.
set kPhases:startInc to 8.
set kPhases:stopInc to 8.

wait until ship:unpacked.

if shouldPhase(0) {
    print "Launch to Orbit!".
    kuniverse:quicksaveto("double_mun_launch").
    ensureHibernate().
    launchToOrbit().
    stageTo(kInterStg).
}
if shouldPhase(1) {
    print "Go to " + first:name.
    local hl to hlIntercept(ship, first).
    add hl:burnNode.
    nodeExecute().
    if not orbit:hasnextpatch() {
        print "Correcting Course".
        waitWarp(time:seconds + 10 * 60).
        set hl to hlIntercept(ship, first).
        add hl:burnNode.
        nodeExecute().
    }
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}
if shouldPhase(2) {
    print "Missing " + first:name.
    refinePe(kMunLow, kCircleHigh).
}
if shouldPhase(3) {
    print "Circling " + first:name.
    circleNextExec(kMunLow).
}
if shouldPhase(4) {
    print "Transfer to Minmus".
    local hi to hohmannIntercept(mun:obt, minmus:obt).
    local arrivalTime to time:seconds + hi:when + hi:duration.
    escapeWith(hi:vd, hi:when).
    nodeExecute().
    wait 1.
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    wait 5.
    if not orbit:hasnextpatch() or orbit:nextpatch:body <> minmus {
        print "Correcting Course".
        // Time after escape.
        local arrivalEta to arrivalTime - time:seconds.
        local dt to .05 * arrivalEta.
        local startTime to time:seconds + dt * kIntercept:StartSpan + 5 * 60.
        local correction to lambertGrid(ship, minmus, startTime, arrivalEta, dt, dt).
        add correction:burnNode.
        nodeExecute().
    }
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}
if shouldPhase(5) {
    print "Missing Minmus".
    refinePe(kMinmusLow, kCircleHigh).

}
if shouldPhase(6) {
    print "Circling Minmus".
    circleNextExec(kMinmusLow).
}
if shouldPhase(7) {
    print "Leaving Minmus".
    escapeWith(-150, 0).
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
    circleAtKerbin().
}
if shouldPhase(8) {
    landKsc().
}