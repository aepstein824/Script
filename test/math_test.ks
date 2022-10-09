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
    "vecClamp", testVecClamp@
).

testRun(tests).

function testSgn {
    local results to list().
    results:add(testEq(sgn(1), 1)).
    results:add(testEq(sgn(100), 1)).
    results:add(testEq(sgn(0.1), 1)).
    results:add(testEq(sgn(-1), -1)).
    results:add(testEq(sgn(-100), -1)).
    results:add(testEq(sgn(-0.1), -1)).
    return results.
}

function testVAA {
    local results to list().
    local pi2 to constant:pi / 2.
    results:add(testEq(vectorAngleAround(unitX, unitY, unitZ), 90)).
    results:add(testEq(vectorAngleAround(2 * unitX, unitY, unitZ), 90)).
    results:add(testEq(vectorAngleAround(unitX, 2 * unitY, unitZ), 90)).
    results:add(testEq(vectorAngleAround(unitX, unitY, unitX), 0)).
    results:add(testEq(vectorAngleAround(unitX, unitY, -1 * unitX), 180)).
    results:add(testEq(vectorAngleAround(unitX, unitY, -1 * unitZ), 270)).
    results:add(testEq(vectorAngleAround(unitY, unitX, unitZ), 270)).
    results:add(testEq(vectorAngleAround(unitX, -1 * unitY, unitZ), 270)).
    results:add(testEq(vectorAngleAround(unitX + unitY, unitY, unitZ), 90)).
    results:add(testEq(vectorAngleAround(unitX + unitY, unitY, 
        unitZ - unitY), 90)).
    results:add(testEq(vectorAngleAroundR(unitX, unitY, unitZ), pi2)).
    return results.
}

function testRVA {
    local r to list().
    r:add(testEq(rotateVecAround(unitX, unitY, 90), unitZ)).
    r:add(testEq(rotateVecAround(unitX, 2 * unitY, 90), unitZ)).
    r:add(testEq(rotateVecAround(2 * unitX, unitY, 90), 2 * unitZ)).
    r:add(testEq(rotateVecAround(2 * unitX, unitY, -90), -2 * unitZ)).
    r:add(testEq(rotateVecAround(unitX, unitY, 90 + 360), unitZ)).
    r:add(testEq(rotateVecAround(unitX, unitX + unitZ, 180), unitZ)).
    return r.
}

function testRemove {
    local r to list().
    r:add(testEq(removeComp(unitX, unitX), zeroV)).
    r:add(testEq(removeComp(unitX + unitY, unitY), unitX)).
    local xm2y1 to -2 * unitX + unitY.
    r:add(testEq(removeComp(xm2y1, unitX), unitY)).
    r:add(testEq(removeComp(xm2y1, unitY), -2 * unitX)).
    r:add(testEq(removeComp(xm2y1, unitZ), xm2y1)).
    return r.
}

function testLerps {
    local r to list().
    r:add(testEq(lerp(0, -2, 2), -2)).
    r:add(testEq(lerp(1, -2, 2), 2)).
    r:add(testEq(lerp(0.5, -2, 2), 0)).
    r:add(testEq(lerp(-100, -2, 2), -2)).
    r:add(testEq(lerp(100, -2, 2), 2)).
    r:add(testEq(invLerp(-2, -2, 2), 0)).
    r:add(testEq(invLerp(2, -2, 2), 1)).
    r:add(testEq(invLerp(0, -2, 2), 0.5)).
    r:add(testEq(invLerp(-100, -2, 2), 0)).
    r:add(testEq(invLerp(100, -2, 2), 1)).
    // these also sufficiently test clamp
    return r.
}

function testPosmod {
    local r to list().
    r:add(testEq(posmod(10, 360), 10)).
    r:add(testEq(posmod(-10, 360), 350)).
    r:add(testEq(posmod(370, 360), 10)).
    r:add(testEq(posmod(-710, 360), 10)).
    r:add(testEq(posmod(-730, 360), 350)).
    return r.
}

function testVecClamp {
    local r to list().
    r:add(testEq(vecClampMag(zeroV, 1), zeroV)).
    r:add(testEq(vecClampMag(unitX, 1), unitX)).
    r:add(testEq(vecClampMag(2 * unitX, 1), unitX)).
    r:add(testEq(vecClampMag(2 * unitX, 2), 2 * unitX)).
    return r.
}