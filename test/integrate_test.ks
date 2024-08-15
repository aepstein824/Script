@LAZYGLOBAL OFF.

runOncePath("0:common/integrate.ks").
runOncePath("0:common/math.ks").
runOncePath("0:test/test_utils.ks").

global kUnityOrbitPeriod to 2 * kPi. // sqrt(4 * pi^2)

local tests to lexicon(
    "proBurnEulerCircle", testProBurnEulerCircle@,
    "proBurnEulerLine", testProBurnEulerLine@,
    "proBurnRk4Circle", testProBurnRk4Circle@,
    "proBurnRk4Line", testProBurnRk4Line@
).

testRun(tests).


function testProBurnEulerCircle {
    local t to list().
    t:add(testEq(proBurnEuler(1, v(1, 0, 0), v(0, 1, 0), 1, 0, 0,
        kUnityOrbitPeriod, 0.01):p, v(1, 0, 0))).
    return t.
}

function testProBurnEulerLine {
    local t to list().
    t:add(testEq(proBurnEuler(0, v(1, 0, 0), v(0, 1, 0), 1, 1, 0,
        1, 0.1):p, v(1, 1.5, 0))).
    return t.
}

function testProBurnRk4Circle {
    local t to list().
    t:add(testEq(proBurnRk4(1, v(1, 0, 0), v(0, 1, 0), 1, 0, 0,
        kUnityOrbitPeriod, 0.1):p, v(1, 0, 0))).
    return t.
}

function testProBurnRk4Line {
    local t to list().
    t:add(testEq(proBurnRk4(0, v(1, 0, 0), v(0, 1, 0), 1, 1, 0,
        1, 0.1):p, v(1, 1.5, 0))).
    return t.
}