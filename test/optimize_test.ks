@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/optimize.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "fixed", testFixed@
).

testRun(tests).

function testFixed {
    local r to list().

    local function parabF {
        parameter pos.
        return pos:x ^ 2 + 4 * pos:y ^2 + 1.
    }
    local function parabCombine {
        parameter posA, posB.
        return posA + posB.
    }
    local function parabSuccess {
        parameter df.
        return df:mag < 2.
    }
    

    local fromZero to optimizeFixedWalk(parabF@, parabCombine@, parabSuccess@, 
        zeroV, 0.1).
    r:add(testEq(fromZero, zeroV, 1)).
    local fromNear to optimizeFixedWalk(parabF@, parabCombine@, parabSuccess@,
        v(20, 1, 0), 0.1).
    r:add(testEq(fromNear, zeroV, 1)).
    local fromFar to optimizeFixedWalk(parabF@, parabCombine@, parabSuccess@,
        v(-40, -2, 0), 0.5).
    r:add(testEq(fromFar, zeroV, 1)).

    return r.
}
