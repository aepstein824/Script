@lazyGlobal off.

runOncePath("0:common/operations").
runOncePath("0:common/phasing").
runOncePath("0:phases/launchToOrbit").

clearAll().
set kClimb:Heading to 0.
set kClimb:Turn to 5.
set kClimb:ClimbAp to 80000.

set kPhases:phase to 0.
if shouldPhase(0) {
    launchQuicksave("kerbin").
    launchToOrbit().
}

