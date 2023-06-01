@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/optimize.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "fixed", testFixed@,
    "solve", testNewtonSolve@
).

testRun(tests).

function testFixed {
    local t to list().

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
    t:add(testEq(fromZero, zeroV, 1)).
    local fromNear to optimizeFixedWalk(parabF@, parabCombine@, parabSuccess@,
        v(20, 1, 0), 0.1).
    t:add(testEq(fromNear, zeroV, 1)).
    local fromFar to optimizeFixedWalk(parabF@, parabCombine@, parabSuccess@,
        v(-40, -2, 0), 0.5).
    t:add(testEq(fromFar, zeroV, 1)).

    return t.
}

function testNewtonSolve {
    local t to list().

    local function fAndD { 
        parameter x.
        return funcAndDeriv({ parameter x_. return (x_^3 - 1).}, x, 1e-12). 
    }.

    t:add(testEq(optimizeNewtonSolve(fAndD@, 1.5), 1)).

    local function fDAndS { 
        parameter x.
        return funcFirstSecondDeriv({
            parameter x_.
            return (x_^2 + 1).}, x, 1e-4). 
    }.

    t:add(testEq(optimizeNewtonSolve(fDAndS@, 1.5), 0)).

    return t.
}
