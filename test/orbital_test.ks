@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "testPlanets", testPlanets@,
    "testVisViva", testVisViva@
).

testRun(tests).

function testPlanets {
    local t to list().
    local testBodies to list().
    list bodies in testBodies.
    testBodies:remove(0).
    local testRatios to list(0.02, 0.1, 0.4, 0.6, 0.9, 0.98).

    for b in testBodies {
        local bobt to b:obt.
        local period to bobt:period.
        local tanlyNow to bobt:trueanomaly.
        for rat in testRatios {
            local elapsed to period * rat.
            local future to time + elapsed.
            // where will it be?
            local whereFuture to positionAt(b, future).
            local tanlyFuture to posToTanly(whereFuture, bobt).
            local timeBetween to timeBetweenTanlies(tanlyNow, tanlyFuture, 
                bobt) / period.
            t:add(testEq(timeBetween, rat)).
        }
    }
    return t.
}

function testVisViva {
    local t to list().

    t:add(testEq(obtVisVivaVFromMuRA(100, 1/50, 1/9), 40)).
    t:add(testEq(obtVisVivaRFromMuVA(100, 40, 1/9), 1/50)).
    t:add(testEq(obtVisVivaAFromMuVR(100, 40, 1/50), 1/9)).

    return t.
}