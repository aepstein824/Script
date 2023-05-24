@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "testPlanets", testPlanets@,
    "testHypers", testHypers@
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
