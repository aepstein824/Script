@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "sgn", testSgn@,
    "vectorAngleAround", testVAA@,
    "rotateVecAround", testRVA@,
    "removeComp", testRemove@,
    "intervals", testLerps@,
    "posmod", testPosmod@,
    "vecClamp", testVecClamp@,
    "smallAng", testSmallAng@,
    "posAng", testPosAng@
).

testRun(tests).

function testSgn {
    local t to list().
    t:add(testEq(sgn(1), 1)).
    t:add(testEq(sgn(100), 1)).
    t:add(testEq(sgn(0.1), 1)).
    t:add(testEq(sgn(-1), -1)).
    t:add(testEq(sgn(-100), -1)).
    t:add(testEq(sgn(-0.1), -1)).
    return t.
}

function testVAA {
    local t to list().
    local pi2 to constant:pi / 2.
    t:add(testEq(vectorAngleAround(unitX, unitY, unitZ), 90)).
    t:add(testEq(vectorAngleAround(2 * unitX, unitY, unitZ), 90)).
    t:add(testEq(vectorAngleAround(unitX, 2 * unitY, unitZ), 90)).
    t:add(testEq(vectorAngleAround(unitX, unitY, unitX), 0)).
    t:add(testEq(vectorAngleAround(unitX, unitY, -1 * unitX), 180)).
    t:add(testEq(vectorAngleAround(unitX, unitY, -1 * unitZ), 270)).
    t:add(testEq(vectorAngleAround(unitY, unitX, unitZ), 270)).
    t:add(testEq(vectorAngleAround(unitX, -1 * unitY, unitZ), 270)).
    t:add(testEq(vectorAngleAround(unitX + unitY, unitY, unitZ), 90)).
    t:add(testEq(vectorAngleAround(unitX + unitY, unitY, 
        unitZ - unitY), 90)).
    t:add(testEq(vectorAngleAroundR(unitX, unitY, unitZ), pi2)).
    t:add(testEq(vectorAngleAround( 
        v(.78, 0, -.62),
        v(0, 1, 0),
        v(-1, 0, 0)), 218.48)).
    return t.
}

function testRVA {
    local t to list().
    t:add(testEq(rotateVecAround(unitX, unitY, 90), unitZ)).
    t:add(testEq(rotateVecAround(unitX, 2 * unitY, 90), unitZ)).
    t:add(testEq(rotateVecAround(2 * unitX, unitY, 90), 2 * unitZ)).
    t:add(testEq(rotateVecAround(2 * unitX, unitY, -90), -2 * unitZ)).
    t:add(testEq(rotateVecAround(unitX, unitY, 90 + 360), unitZ)).
    t:add(testEq(rotateVecAround(unitX, unitX + unitZ, 180), unitZ)).
    return t.
}

function testRemove {
    local t to list().
    t:add(testEq(removeComp(unitX, unitX), zeroV)).
    t:add(testEq(removeComp(unitX + unitY, unitY), unitX)).
    local xm2y1 to -2 * unitX + unitY.
    t:add(testEq(removeComp(xm2y1, unitX), unitY)).
    t:add(testEq(removeComp(xm2y1, unitY), -2 * unitX)).
    t:add(testEq(removeComp(xm2y1, unitZ), xm2y1)).
    return t.
}

function testLerps {
    local t to list().
    t:add(testEq(lerp(0, -2, 2), -2)).
    t:add(testEq(lerp(1, -2, 2), 2)).
    t:add(testEq(lerp(0.5, -2, 2), 0)).
    t:add(testEq(lerp(-100, -2, 2), -2)).
    t:add(testEq(lerp(100, -2, 2), 2)).
    t:add(testEq(invLerp(-2, -2, 2), 0)).
    t:add(testEq(invLerp(2, -2, 2), 1)).
    t:add(testEq(invLerp(0, -2, 2), 0.5)).
    t:add(testEq(invLerp(-100, -2, 2), 0)).
    t:add(testEq(invLerp(100, -2, 2), 1)).
    // these also sufficiently test clamp
    return t.
}

function testPosmod {
    local t to list().
    t:add(testEq(posmod(10, 360), 10)).
    t:add(testEq(posmod(-10, 360), 350)).
    t:add(testEq(posmod(370, 360), 10)).
    t:add(testEq(posmod(-710, 360), 10)).
    t:add(testEq(posmod(-730, 360), 350)).
    return t.
}

function testVecClamp {
    local t to list().
    t:add(testEq(vecClampMag(zeroV, 1), zeroV)).
    t:add(testEq(vecClampMag(unitX, 1), unitX)).
    t:add(testEq(vecClampMag(2 * unitX, 1), unitX)).
    t:add(testEq(vecClampMag(2 * unitX, 2), 2 * unitX)).
    return t.
}

function testSmallAng {
    local t to list().
    t:add(testEq(smallAng(-1), -1)).
    t:add(testEq(smallAng(1), 1)).
    t:add(testEq(smallAng(-181), 179)).
    t:add(testEq(smallAng(181), -179)).
    t:add(testEq(smallAng(-541), 179)).
    t:add(testEq(smallAng(541), -179)).
    return t.
}

function testPosAng {
    local t to list().
    t:add(testEq(posAng(-1), 359)).
    t:add(testEq(posAng(1), 1)).
    t:add(testEq(posAng(-181), 179)).
    t:add(testEq(posAng(181), 181)).
    t:add(testEq(posAng(-541), 179)).
    t:add(testEq(posAng(541), 181)).
    return t.
}