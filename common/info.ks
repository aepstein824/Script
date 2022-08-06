@LAZYGLOBAL OFF.

global kWarpHeights to Lexicon().
set kWarpHeights[moho] to 11000.
set kWarpHeights[eve] to 100000.
set kWarpHeights[kerbin] to 75000.
set kWarpHeights[mun] to 10500.
set kWarpHeights[minmus] to 6500.
set kWarpHeights[duna] to 100000.
set kWarpHeights[ike] to 10500.
set kWarpHeights[dres] to 10500.
set kWarpHeights[laythe] to 55000.
set kWarpHeights[eeloo] to 5000.

global sToDays to 1 / 6 / 60 / 60.
global sToHours to 1 / 60 / 60.
global cosmicNorth to v(0, 1, 0).

function polarScannerAltitude {
    parameter b.

    return 3 * max(25000, kWarpHeights[b]).
}