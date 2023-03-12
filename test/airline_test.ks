@LAZYGLOBAL OFF.

runOncePath("0:phases/airline.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "testVspd", testCruiseVspd@,
    "testTurnError", testTurnError@,
    "testErrorToXaccCW", testErrorToXaccCW@,
    "testErrorToXaccCCW", testErrorToXaccCCW@,
    "testLandY", testLandY@
).

testRun(tests).

function testCruiseVspd {
    local t to list().
    local lim to 30.
    local h to 1000.
    t:add(testEq(airlineCruiseVspd(h, h, lim), 0)).
    t:add(testLs(airlineCruiseVspd(h, h + 1, lim), 0)).
    t:add(testGr(airlineCruiseVspd(h, h - 1, lim), 0)).
    set kAirline:DiffToVspd to 1.
    t:add(testEq(airlineCruiseVspd(0, 10000, lim, 10000), -5000)).
    t:add(testEq(airlineCruiseVspd(0, -10000, lim, 10000), 5000)).
    return t.
}

function testTurnError {
    local t to list().
    local turnR to turn2d(100 * unitX, 10, zeroR).
    local turnL to turn2d(100 * unitX, 10, leftR).
    // far away
    local farAwayR to v(110, 0, -100).
    t:add(testEq(airlineTurnError(turnR, farAwayR, v(0,0,1)), 0)).
    t:add(testEq(airlineTurnError(turnR, farAwayR, v(1,0,1)), 45)).
    t:add(testEq(airlineTurnError(turnR, farAwayR, v(-1,0,1)), -45)).
    local farAwayL to v(90, 0, -100).
    t:add(testEq(airlineTurnError(turnL, farAwayL, v(0,0,1)), 0)).
    t:add(testEq(airlineTurnError(turnL, farAwayL, v(1,0,1)), 45)).
    t:add(testEq(airlineTurnError(turnL, farAwayL, v(-1,0,1)), -45)).
    // inside the circle
    local inside to v(9, 0, 0).
    local insideV to unitZ.
    t:add(testLs(airlineTurnError(turnR, inside, insideV), 0)).
    t:add(testGr(airlineTurnError(turnL, -inside, -insideV), 0)).
    return t.
}

function testErrorToXaccCW {
    local t to list().
    set kAirline:MaxTurnAngle to 10.
    set kAirline:TurnR to 0.1.
    local turnX to 4.
    local tp1 to 5.
    local turnO to 1 + 0.9 * kAirline:TurnR.
    local turnI to 1 - 0.9 * kAirline:TurnR.
    // within the turn zone
    t:add(testEq(airlineTurnErrorToXacc(0, 1, turnX, false), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, 1, turnX, false), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, 1, turnX, false), turnX + 1)).
    t:add(testEq(airlineTurnErrorToXacc(0, turnO, turnX, false), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, turnO, turnX, false), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, turnO, turnX, false), turnX + 1)).
    t:add(testEq(airlineTurnErrorToXacc(0, turnI, turnX, false), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, turnI, turnX, false), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, turnI, turnX, false), turnX + 1)).
    // inside the circle 
    t:add(testEq(airlineTurnErrorToXacc(0, 0.1, turnX, false), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, 0.1, turnX, false), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, 0.1, turnX, false), turnX + 1)).
    // outside the turn zone
    t:add(testEq(airlineTurnErrorToXacc(0, 3, turnX, false), 0)).
    t:add(testEq(airlineTurnErrorToXacc(10, 3, turnX, false), tp1 * -1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, 3, turnX, false), tp1)).
    // linear
    t:add(testEq(airlineTurnErrorToXacc(5, 1, turnX, false), turnX - 0.5)).
    t:add(testEq(airlineTurnErrorToXacc(5, 0.1, turnX, false), turnX - 0.5)).
    t:add(testEq(airlineTurnErrorToXacc(5, 3, turnX, false), tp1 * -.5)).
    return t.
}

function testErrorToXaccCCW {
    local t to list().
    set kAirline:MaxTurnAngle to 10.
    set kAirline:TurnR to 0.1.
    local turnX to -4.
    local tp1 to 5. // positive since it's only for outside
    local turnO to 1 + 0.9 * kAirline:TurnR.
    local turnI to 1 - 0.9 * kAirline:TurnR.
    // within the turn zone
    t:add(testEq(airlineTurnErrorToXacc(0, 1, -turnX, true), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, 1, -turnX, true), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, 1, -turnX, true), turnX + 1)).
    t:add(testEq(airlineTurnErrorToXacc(0, turnO, -turnX, true), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, turnO, -turnX, true), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, turnO, -turnX, true), turnX + 1)).
    t:add(testEq(airlineTurnErrorToXacc(0, turnI, -turnX, true), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, turnI, -turnX, true), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, turnI, -turnX, true), turnX + 1)).
    // inside the circle 
    t:add(testEq(airlineTurnErrorToXacc(0, 0.1, -turnX, true), turnX)).
    t:add(testEq(airlineTurnErrorToXacc(10, 0.1, -turnX, true), turnX - 1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, 0.1, -turnX, true), turnX + 1)).
    // outside the turn zone
    t:add(testEq(airlineTurnErrorToXacc(0, 3, -turnX, true), 0)).
    t:add(testEq(airlineTurnErrorToXacc(10, 3, -turnX, true), tp1 * -1)).
    t:add(testEq(airlineTurnErrorToXacc(-10, 3, -turnX, true), tp1)).
    // linear
    t:add(testEq(airlineTurnErrorToXacc(5, 1, -turnX, true), turnX - 0.5)).
    t:add(testEq(airlineTurnErrorToXacc(5, 0.1, -turnX, true), turnX - 0.5)).
    t:add(testEq(airlineTurnErrorToXacc(5, 3, -turnX, true), tp1 * -.5)).
    return t.
}

function testLandY {
    local t to list().
    local runwayAlti to 100.
    local shallowS to 5.
    local extraOver to 10.
    local extraShallow to 10.
    local tanGlide to -0.1. // a little more than 5 degrees
    local landV to 50.
    local descentV to -1.

    local resOver to airlineLandY(runwayAlti, shallowS, extraOver, extraShallow,
        tanGlide, landV, descentV, -10).
    t:add(testEq(resOver:spd, descentV)).
    local resShal0 to airlineLandY(runwayAlti, shallowS, extraOver, extraShallow,
        tanGlide, landV, descentV, 0).
    t:add(testEq(resShal0:y, 110)).
    t:add(testEq(resShal0:spd, descentV)).
    local resShal1 to airlineLandY(runwayAlti, shallowS, extraOver, extraShallow,
        tanGlide, landV, descentV, 50).
    t:add(testEq(resShal1:y, 111)).
    t:add(testEq(resShal1:spd, descentV)).
    local resShal3 to airlineLandY(runwayAlti, shallowS, extraOver, extraShallow,
        tanGlide, landV, descentV, 150).
    t:add(testEq(resShal3:y, 113)).
    t:add(testEq(resShal3:spd, descentV)).
    local resShal3 to airlineLandY(runwayAlti, shallowS, extraOver, extraShallow,
        tanGlide, landV, descentV, 150).
    t:add(testEq(resShal3:y, 113)).
    t:add(testEq(resShal3:spd, descentV)).
    local resGlide0 to airlineLandY(runwayAlti, shallowS, extraOver, extraShallow,
        tanGlide, landV, descentV, 250).
    t:add(testEq(resGlide0:y, 125)).
    t:add(testEq(resGlide0:spd, -5)).
    local resGlide5 to airlineLandY(runwayAlti, shallowS, extraOver, extraShallow,
        tanGlide, landV, descentV, 500).
    t:add(testEq(resGlide5:y, 150)).
    t:add(testEq(resGlide5:spd, -5)).
    
    return t.
}