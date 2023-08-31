@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
clearAll().

// Testing
set kPhases:startInc to 0.
set kPhases:stopInc to 4.
// set kPhases:phase to 4.

// Launch
set kClimb:VertV to 40.
set kClimb:SteerV to 150.
set kClimb:Turn to 9.

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("shoddle").
    launchToOrbit().
    wait 3.
}
if shouldPhase(1) {
    print "Correcting circularization".
    circleNextExec(75000).
    wait 1.
}
if shouldPhase(2) {
    landPlaneDeorbit().
}
if shouldPhase(3) {
    landPlaneReentry().
}
if shouldPhase(4) {
    landPlaneRunway().
}
