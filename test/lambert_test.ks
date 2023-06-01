@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/optimize.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    // "testPlanets", testPlanets@,
    "testHypers", testHypers@,
    "testLGrid", testLGrid@,
    "testLOptimize", testLOptimize@
).

testRun(tests).

function testPlanets {
    local t to list().
    local testBodies to list().
    list bodies in testBodies.
    testBodies:remove(0).
    local testRatios to list(0.1, 0.4, 0.6, 0.9, 0.98).

    local startTime to time.
    local iterCount to 0.
    for b in testBodies {
        local bobt to b:obt.
        local period to bobt:period.
        for rat in testRatios {
            set iterCount to iterCount + 1.
            local elapsed to period * rat.

            local lamb to lambertIntercept(b, b, time, elapsed).
            if lamb:haskey("burnvec") {
                t:add(testEq(lamb:burnVec, zeroV, 2)).
            } else {
                t:add(lamb).
            }
        }
    }
    local endTime to time.
    local duration to detimestamp(endTime - startTime).
    print "Each lambert takes " + (50 * 2000 * duration / iterCount).
    return t.
}

function testHypers {
    local t to list().
    local testBodies to list().
    list bodies in testBodies.
    testBodies:remove(0).
    local testRatios to list(0.3).

    local startTime to time.
    local iterCount to 0.
    for b in testBodies {
        local bobt to b:obt.
        local period to bobt:period.
        for rat in testRatios {
            set iterCount to iterCount + 1.
            local elapsed to period * rat.

            local lamb to lambertPosOnly(b, 2000 * unitX, time, bobt:period/99).
            if not lamb:haskey("burnvec") {
                t:add(lamb).
            }
        }
    }
    local endTime to time.
    local duration to detimestamp(endTime - startTime).
    print "Each lambert takes " + (50 * 2000 * duration / iterCount).
    return t.
}

function testLGrid {
    local begin to time.
    local grid to hlIntercept(kerbin, dres).
    if grid:haskey("burnvec") {
        print "-- Double " + round(grid:burnVec:mag)
            + " in " + round(detimestamp(time - begin)) + " --".
        print "  ++ " + timeRoundStr(grid:start - time:seconds).
        print "  ++ " + timeRoundStr(grid:duration).
    }
    return list().
}

function testLOptimize {
    local begin to time.
    local hi to hohmannIntercept(kerbin:obt, dres:obt).
    local function f{
        parameter x.
        local lamb to lambertIntercept(kerbin, dres, hi:start, x).
        return lamb:burnVec:mag.
    }
    local function fDAndS{
        parameter x.
        return funcFirstSecondDeriv(f@, x, 1).
    }
    local bestDuration to optimizeNewtonSolve(fDAndS@, hi:duration).
    local bestLamb to lambertIntercept(kerbin, dres, hi:start, bestDuration).
    print "-- Double " + round(bestLamb:burnVec:mag)
        + " in " + round(detimestamp(time - begin)) + " --".
    return list().
}
