@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/landAtm.ks").

set kLandAtm:ReturnTanly to 180.
set kLandAtm:Winged to true.

if altitude > 70000 {
    planLandingBurn().
    nodeExecute().
}
landFromDeorbit().
print "Hoped to land at " + waypoint("ksc"):geoposition.
