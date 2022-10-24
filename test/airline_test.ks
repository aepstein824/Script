@LAZYGLOBAL OFF.

runOncePath("0:phases/airline.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "testVspd", testCruiseVspd@,
    "testTurnError", testTurnError@,
    "testErrorToXacc", testErrorToXacc@
).

testRun(tests).

function testCruiseVspd {
    local r to list().
    local lim to 3.
    local h to 1000.
    r:add(testEq(airlineCruiseVspd(h, h, lim), 0)).
    r:add(testLs(airlineCruiseVspd(h, h + 1, lim), 0)).
    r:add(testGr(airlineCruiseVspd(h, h - 1, lim), 0)).
    r:add(testEq(airlineCruiseVspd(0, 10000, lim), -lim)).
    r:add(testEq(airlineCruiseVspd(0, -10000, lim), lim)).
    return r.
}

function testTurnError {
    local r to list().
    local turnR to turn2d(100 * unitX, 10, zeroR).
    local turnL to turn2d(100 * unitX, 10, leftR).
    // far away
    local farAwayR to v(110, 0, -100).
    r:add(testEq(airlineTurnError(turnR, farAwayR, v(0,0,1)), 0)).
    r:add(testEq(airlineTurnError(turnR, farAwayR, v(1,0,1)), 45)).
    r:add(testEq(airlineTurnError(turnR, farAwayR, v(-1,0,1)), -45)).
    local farAwayL to v(90, 0, -100).
    r:add(testEq(airlineTurnError(turnL, farAwayL, v(0,0,1)), 0)).
    r:add(testEq(airlineTurnError(turnL, farAwayL, v(1,0,1)), 45)).
    r:add(testEq(airlineTurnError(turnL, farAwayL, v(-1,0,1)), -45)).
    // inside the circle
    local inside to v(9, 0, 0).
    local insideV to unitZ.
    r:add(testLs(airlineTurnError(turnR, inside, insideV), 0)).
    r:add(testGr(airlineTurnError(turnL, -inside, -insideV), 0)).
    return r.
}

function testErrorToXacc {
    local r to list().
    set kAirline:MaxTurnAngle to 10.
    set kAirline:TurnR to 0.1.
    local turnX to 4.
    local turnO to 1 + 0.9 * kAirline:TurnR.
    local turnI to 1 - 0.9 * kAirline:TurnR.
    // within the turn zone
    r:add(testEq(airlineTurnErrorToXacc(0, 1, turnX), turnX)).
    r:add(testEq(airlineTurnErrorToXacc(10, 1, turnX), turnX - 1)).
    r:add(testEq(airlineTurnErrorToXacc(-10, 1, turnX), turnX + 1)).
    r:add(testEq(airlineTurnErrorToXacc(0, turnO, turnX), turnX)).
    r:add(testEq(airlineTurnErrorToXacc(10, turnO, turnX), turnX - 1)).
    r:add(testEq(airlineTurnErrorToXacc(-10, turnO, turnX), turnX + 1)).
    r:add(testEq(airlineTurnErrorToXacc(0, turnI, turnX), turnX)).
    r:add(testEq(airlineTurnErrorToXacc(10, turnI, turnX), turnX - 1)).
    r:add(testEq(airlineTurnErrorToXacc(-10, turnI, turnX), turnX + 1)).
    // inside the circle 
    r:add(testEq(airlineTurnErrorToXacc(0, 0.1, turnX), turnX)).
    r:add(testEq(airlineTurnErrorToXacc(10, 0.1, turnX), turnX - 1)).
    r:add(testEq(airlineTurnErrorToXacc(-10, 0.1, turnX), turnX + 1)).
    // outside the turn zone
    r:add(testEq(airlineTurnErrorToXacc(0, 3, turnX), 0)).
    r:add(testEq(airlineTurnErrorToXacc(10, 3, turnX), turnX * -1)).
    r:add(testEq(airlineTurnErrorToXacc(-10, 3, turnX), turnX)).
    // linear
    r:add(testEq(airlineTurnErrorToXacc(5, 1, turnX), turnX - 0.5)).
    r:add(testEq(airlineTurnErrorToXacc(5, 0.1, turnX), turnX - 0.5)).
    r:add(testEq(airlineTurnErrorToXacc(5, 3, turnX), turnX * -0.5)).
    return r.
}