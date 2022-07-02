@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/landAtm.ks").

set kLandAtm:Winged to true.

planLandingBurn().
nodeExecute().
landFromDeorbit().