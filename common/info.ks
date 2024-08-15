@LAZYGLOBAL OFF.

global kWarpHeights to Lexicon().
set kWarpHeights[moho] to 11000.
set kWarpHeights[eve] to 320000.
set kWarpHeights[gilly] to 10000.
set kWarpHeights[kerbin] to 75000.
set kWarpHeights[mun] to 25500.
set kWarpHeights[minmus] to 12500.
set kWarpHeights[duna] to 100000.
set kWarpHeights[ike] to 15500.
set kWarpHeights[dres] to 10500.
set kWarpHeights[jool] to 1000000.
set kWarpHeights[pol] to 10000.
set kWarpHeights[bop] to 30000.
set kWarpHeights[tylo] to 20000.
set kWarpHeights[vall] to 20000.
set kWarpHeights[laythe] to 55000.
set kWarpHeights[eeloo] to 5000.

global sToHours to 1 / 60 / 60.
global sToDays to sToHours / 6.
global sToYears to sToDays / kerbin:obt:period.
global cosmicNorth to v(0, 1, 0).

function polarScannerAltitude {
    parameter b.

    return 3 * max(25000, kWarpHeights[b]).
}