@lazyglobal off.

runPath("0:/deps/kLA-ks/src/kla.ks").

klaPrint(klaZeros(4, 8)).
print " ".

klaPrint(klaOnes(3, 6)).
print " ".

klaPrint(klaEye(5)).
print " ".

local a is klaColumns(List(List(1, 1, 1, 1), List(-1, 4, 4, -1), List(4, -2, 2, 0))).
local qr is klaQRDecompose(a).

klaPrint(a).
print " ".

klaPrint(qr[0]).
print " ".

klaPrint(qr[1]).
print " ".

print " --- ".
local a is klaRows(List(List(2, 0), List(-1, 1), List(0, 2))).
klaPrint(a).
print " ".
local b is klaColumns(List(List(1, 0, -1))).
klaPrint(b).
print " ".
local x is klaBackslash(a, b).
klaPrint(x).
print " ".
