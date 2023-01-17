@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/landAtm.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/launchToOrbit.ks").

// Mission parameters
local landingPe to 0.

// Testing
set kPhases:startInc to 2.
set kPhases:stopInc to 3.
// set kPhases:phase to 3.

// Launch
set kClimb:VertV to 40.
set kClimb:SteerV to 150.
set kClimb:Turn to 9.

local function dynamicPres {
    parameter alti, spd.
    return 0.5 * body:atm:altitudepressure(alti) * (spd ^ 2).
}

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("shoddle_launch").
    launchToOrbit().
    wait 3.
}
if shouldPhase(1) {
    rcs off.
    circleNextExec(75000).
    wait 1.
}
if shouldPhase(2) {
    set kLandAtm:ReturnTanly to 90.
    set kLandAtm:EntryPe to 0.
    planLandingBurn().
    nodeExecute().
    stageTo(0).

    getToAtm().
}
if shouldPhase(3) {
    print geoPosition.
    controlLock().
    set controlThrot to 0.
    local aoa to 90.

    until altitude < 20000 or airspeed < 700 {
        local dyn to dynamicPres(altitude, airspeed).
        // if dyn < 130 {
        //     set aoa to 90.
        // } else if dyn < 550 {
        //     set aoa to 45.
        // } else if dyn < 1100 {
        //     set aoa to 30.
        // } else if dyn < 4370 {
        //     set aoa to 15.
        // } else if dyn < 9000 {
        //     set aoa to 10.
        // } else if dyn < 30000 {
        //     set aoa to 5.
        if dyn > 30000 {
            set aoa to 2.
        } else {
            set aoa to 900 / sqrt(max(dyn, 1)).
            set aoa to clamp(aoa, 2, 90).
        }
        // print round(dyn) + ", " + round(aoa, 2).

        set controlSteer to srfPrograde * r(-aoa, 0, 0).
        wait 0.
    }
    print geoPosition.
}
if shouldPhase(4) {
    lock steering to srfPrograde.
    lock throttle to 1.
    wait 2.
}

