@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/landAtm.ks").

set kLandAtm:ReturnTanly to 120.
set kLandAtm:Winged to true.

planLandingBurn().
nodeExecute().
landFromDeorbit().
print "Hoped to land at " + waypoint("ksc"):geoposition.
