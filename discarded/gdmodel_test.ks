@LAZYGLOBAL OFF.

runOncePath("0:common/math").
runOncePath("0:common/gdmodel").
runOncePath("0:test/test_utils").

local m to gdmodelQuad().

local tests to lexicon(
    "zero", testZero@,
    "constant", testConstant@,
    "convergence", testConvergence@,
    "wide", testWide@
).
testRun(tests).

function testZero {
    local r to list().
    local x to 1.
    local y to 0.
    local t to lexicon("a", 2, "b", 0, "c", -2).
    local wOut to gdmodelUpdate(m, t, y, x).
    r:add(testEq(wOut, t)).
    return r.
}

function testConstant {
    local r to list().
    local t to lexicon("a", 0, "b", 0, "c", -2).
    local w to lexicon("a", 0, "b", 0, "c", 0).
    local count to 100.0.
    for i in range(count + 1) {
        local x to 0.
        local yTgt to m:func(t, x).
        // print "x " + x + ", y " + yTgt + ", ym " + m:func(w, x)
        //     + ", m " + m:grad(w, x).
        set w to gdmodelUpdate(m, w, yTgt, x, 0.1).
    }
    r:add(testEq(w, t)).
    return r.
}

function testConvergence {
    local r to list().
    local t to lexicon("a", 1, "b", -1, "c", -2).
    local w to lexicon("a", 0.5, "b", -0.5, "c", -1).
    local count to 100.0.
    for i in range(count + 1) {
        local x to list(-1, 1, 0, -0.5, 0.5)[mod(i, 5)].
        local yTgt to m:func(t, x).
        // print "x " + x + ", y " + yTgt + ", ym " + m:func(w, x)
        //     + ", w " + w.
        set w to gdmodelUpdate(m, w, yTgt, x, 0.1).
    }
    r:add(testEq(w, t, 0.1)).
    return r.
}

function testWide {
    local r to list().
    local t to lexicon("a", 0.1, "b", 1, "c", 5).
    local w to lexicon("a", 0.05, "b", 0.2, "c", 6).
    local count to 100.0.
    for i in range(count + 1) {
        local x to list(-100, 100, 0, 5, -5)[mod(i, 5)].
        local yTgt to m:func(t, x).
        // print "x " + x + ", y " + yTgt + ", ym " + m:func(w, x)
        //     + ", w " + w.
        set w to gdmodelUpdate(m, w, yTgt, x, 0.1).
    }
    r:add(testEq(w, t, 0.1)).
    return r.
}