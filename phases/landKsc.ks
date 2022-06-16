@LAZYGLOBAL OFF.
clearscreen.

wait until ship:unpacked.

runPath("0:maneuvers/atmLand.ks").

atmLandInit().
until atmLandSuccess() {
    atmLandLoop().
}
