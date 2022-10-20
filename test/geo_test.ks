@LAZYGLOBAL OFF.

runOncePath("0:common/geo.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "northFrame", testNorth@,
    "approach", testApproach@,
    "turnCircles", testTurnCircles@,
    "turnXVec", testTurnIntersectVec@,
    "turnXPoint", testTurnIntersectPoint@,
    "turnLL", testTurnPathLLSimple@,
    "turnRR", testTurnPathRRSimple@,
    "turnLR", testTurnPathLRSimple@,
    "turnRL", testTurnPathRLSimple@,
    "turnDrafted", testTurnDrafted@,
    "turnLRL", testTurnPathLRLSimple@,
    "turnRLR", testTurnPathRLRSimple@,
    "turnTooFar", testTurnPathCCTooFar@
).

testRun(tests).

function testNorth {
    local r to list().
    local shipNorth to geoNorthFrame(ship:geoposition).
    local headNorth to heading(0, 0).
    r:add(testEq(shipNorth:forevector, headNorth:forevector)).
    r:add(testEq(shipNorth:upvector, headNorth:upvector)).
    local geo0 to latlng(0, 0).
    local north0 to geoNorthFrame(geo0).
    r:add(testEq(north0:forevector, unitY)).
    local geo1 to latlng(45, 0).
    local north1 to geoNorthFrame(geo1).
    local rot1 to rotateVecAround(unitY, north0:rightvector, -45).
    r:add(testEq(north1:forevector, rot1)).
    return r.
}

function testApproach {
    local r to list().
    local geo0 to latlng(10, 10).
    local approachGeo to geoApproach(geo0, 90, 1000).
    r:add(testEq(approachGeo:lat, geo0:lat)).
    r:add(testGr(approachGeo:lng, geo0:lng)).
    return r.
}

function testTurnCircles {
    local r to list().
    local right to turnFromPoint(zeroV, zeroR, 10, 1). 
    r:add(testEq(right:p, v(10, 0, 0))).
    r:add(testEq(right:d:forevector, v(0, 0, 1))).
    r:add(testEq(right:d:upvector, v(0, -1, 0))).
    r:add(testEq(right:d:rightvector, v(-1, 0, 0))).
    local left to turnFromPoint(zeroV, zeroR, 10, -1). 
    r:add(testEq(left:p, v(-10, 0, 0))).
    r:add(testEq(left:d:forevector, v(0, 0, 1))).
    r:add(testEq(left:d:upvector, v(0, 1, 0))).
    r:add(testEq(left:d:rightvector, v(1, 0, 0))).
    return r.
}

function testTurnIntersectVec {
    local r to list().
    local og to unitZ.
    local testRCircle to turn2d(og, 1, zeroR).
    r:add(testEq(turnIntersectVec(testRCircle, unitZ), og + unitX)).
    r:add(testEq(turnIntersectVec(testRCircle, unitX), zeroV)).
    r:add(testEq(turnIntersectVec(testRCircle, 50 * unitX), zeroV)).
    local testLCircle to turn2d(og, 1, r(0, 0, 180)).
    r:add(testEq(turnIntersectVec(testLCircle, unitZ), og - unitX)).
    r:add(testEq(turnIntersectVec(testLCircle, unitX), 2 * unitZ)).
    return r.
}

function testTurnIntersectPoint {
    local r to list().
    local og to unitZ.
    local testRCircle to turn2d(og, 2, zeroR).
    local cornerXZ to 2 * unitX + 2 * unitZ + og.
    local cornerXMZ to 2 * unitX - 2 * unitZ + og.
    r:add(testEq(turnIntersectPoint(testRCircle, cornerXZ), og + 2 * unitZ)).
    r:add(testEq(turnIntersectPoint(testRCircle, cornerXMZ), og + 2 * unitX)).
    local testLCircle to turn2d(og, 2, r(0, 0, 180)).
    r:add(testEq(turnIntersectPoint(testLCircle, cornerXZ), og + 2 * unitX)).
    r:add(testEq(turnIntersectPoint(testLCircle, cornerXMZ), og - 2 * unitZ)).
    return r.
}

function testTurnPathLLSimple {
   local r to list().
   local left0 to turn2d(v(1,0,0), 1, leftR).
   local left1 to turn2d(v(1,0,5), 1, leftR).
   local path to turnToTurn(left1, left0).
   r:add(testEq(path[0][0], "start")).
   r:add(testEq(path[0][1], v(0, 0, 5))).
   r:add(testEq(path[1][0], "turn")).
   r:add(testEq(path[1][1], v(2, 0, 5))).
   r:add(testEq(path[2][0], "straight")).
   r:add(testEq(path[2][1], v(2, 0, 0))).
   r:add(testEq(path[3][0], "turn")).
   r:add(testEq(path[3][1], v(0, 0, 0))).
   return r.
}

function testTurnPathRRSimple {
   local r to list().
   local right0 to turn2d(v(1,0,0), 1, zeroR).
   local right1 to turn2d(v(1,0,5), 1, zeroR).
   local path to turnToTurn(right1, right0).
   r:add(testEq(path[0][0], "start")).
   r:add(testEq(path[0][1], v(2, 0, 5))).
   r:add(testEq(path[1][0], "turn")).
   r:add(testEq(path[1][1], v(0, 0, 5))).
   r:add(testEq(path[2][0], "straight")).
   r:add(testEq(path[2][1], v(0, 0, 0))).
   r:add(testEq(path[3][0], "turn")).
   r:add(testEq(path[3][1], v(2, 0, 0))).
   return r.
}

function testTurnPathLRSimple {
   local r to list().
   local right0 to turn2d(v(1,0,0), 1, zeroR).
   local left1 to turn2d(v(-1,0,5), 1, leftR).
   local path to turnToTurn(left1, right0).
   r:add(testEq(path[0][0], "start")).
   r:add(testEq(path[0][1], v(-2, 0, 5))).
   r:add(testEq(path[1][0], "turn")).
   r:add(testEq(path[1][1], v(0, 0, 5))).
   r:add(testEq(path[2][0], "straight")).
   r:add(testEq(path[2][1], v(0, 0, 0))).
   r:add(testEq(path[3][0], "turn")).
   r:add(testEq(path[3][1], v(2, 0, 0))).
   return r.
}

function testTurnPathRLSimple {
   local r to list().
   local left0 to turn2d(v(-1,0,0), 1, leftR).
   local right1 to turn2d(v(1,0,5), 1, zeroR).
   local path to turnToTurn(right1, left0).
   r:add(testEq(path[0][0], "start")).
   r:add(testEq(path[0][1], v(2, 0, 5))).
   r:add(testEq(path[1][0], "turn")).
   r:add(testEq(path[1][1], v(0, 0, 5))).
   r:add(testEq(path[2][0], "straight")).
   r:add(testEq(path[2][1], v(0, 0, 0))).
   r:add(testEq(path[3][0], "turn")).
   r:add(testEq(path[3][1], v(-2, 0, 0))).
   return r.
}

function testTurnDrafted {
    local r to list().

    // I drew a bunch of circles with a ruler and compass and measured them.
    local al to turn2d(v(6, 0, 12), 0.001, leftR).
    local ar to turn2d(v(6, 0, 12), 0.001, zeroR).
    local bl to turn2d(v(0, 0, 11), 1, leftR).
    local br to turn2d(v(0, 0, 11), 1, zeroR).
    local cl to turn2d(v(7, 0, 8), 3, leftR).
    local cr to turn2d(v(7, 0, 8), 3, zeroR).
    local dl to turn2d(v(3, 0, 4), 1, leftR).
    local dr to turn2d(v(3, 0, 4), 1, zeroR).
    local el to turn2d(v(4, 0, 2), 2, leftR).
    local er to turn2d(v(4, 0, 2), 2, zeroR).

    // check destination positions from A
    local albr to turnToTurn(al, br)[2][1].
    r:add(testEq(albr, v(0, 0, 12), 0.5)).
    local arcl to turnToTurn(ar, cl)[2][1].
    r:add(testEq(arcl, v(8, 0, 10.5), 0.5)).
    local aldr to turnToTurn(al, dr)[2][1].
    r:add(testEq(aldr, v(2.5, 0, 4.5), 0.5)).
    local arel to turnToTurn(ar, el)[2][1].
    r:add(testEq(arel, v(6, 0, 2), 0.5)).

    // check src positions from B
    local brar to turnToTurn(br, ar)[1][1].
    r:add(testEq(brar, v(0.5, 0, 10), 0.5)).
    local blcl to turnToTurn(bl, cl)[1][1].
    r:add(testEq(blcl, v(0.5, 0, 12), 0.5)).
    local bldl to turnToTurn(bl, dl)[1][1].
    r:add(testEq(bldl, v(1, 0, 11.5), 0.5)).
    local blel to turnToTurn(bl, el)[1][1].
    r:add(testEq(blel, v(1, 0, 11.5), 0.5)).

    // check dst positions from C, except A
    local crar to turnToTurn(cr, ar)[1][1].
    r:add(testEq(crar, v(8.5, 0, 10.5), 0.5)).
    local clbr to turnToTurn(cl, br)[2][1].
    r:add(testEq(clbr, v(1, 0, 11.5), 0.5)).
    local cldr to turnToTurn(cl, dr)[2][1].
    r:add(testEq(cldr, v(3, 0, 5), 0.5)).
    local crer to turnToTurn(cr, er)[2][1].
    r:add(testEq(crer, v(2, 0, 2.5), 0.5)).

    // check src positions from D
    local drar to turnToTurn(dr, ar)[1][1].
    r:add(testEq(drar, v(4, 0, 4), 0.5)).
    local dlbl to turnToTurn(dl, bl)[1][1].
    r:add(testEq(dlbl, v(2, 0, 3.5), 0.5)).
    local drcr to turnToTurn(dr, cr)[1][1].
    r:add(testEq(drcr, v(3.5, 0, 3), 0.5)).
    local drer to turnToTurn(dr, er)[1][1].
    r:add(testEq(drer, v(2, 0, 4), 0.5)).

    // check dst positions from E
    local elar to turnToTurn(el, ar)[2][1].
    r:add(testEq(elar, v(6, 0, 12), 0.5)).
    local elbr to turnToTurn(el, br)[2][1].
    r:add(testEq(elbr, v(1, 0, 11), 0.5)).
    local elcr to turnToTurn(el, cr)[2][1].
    r:add(testEq(elcr, v(8, 0, 5), 0.5)).
    local eldl to turnToTurn(el, dl)[2][1].
    r:add(testEq(eldl, v(2, 0, 4), 0.5)).

    return r.
}

function testTurnPathLRLSimple {
    local r to list().
    local start to turn2d(-unitX, 1, zeroR).
    local end to turn2d(unitX, 1, zeroR).
    local uturn to turnToTurnCC(start, end).
    r:add(testEq(uturn[1][1], v(-0.5, 0, sqrt(3/4)))).
    r:add(testEq(uturn[2][1], v(0.5, 0, sqrt(3/4)))).
    r:add(testEq(uturn[2][2]:p, v(0, 0, sqrt(3)))).
    return r.
}

function testTurnPathRLRSimple {
    local r to list().
    local start to turn2d(unitX, 1, leftR).
    local end to turn2d(-unitX, 1, leftR).
    local uturn to turnToTurnCC(start, end).
    r:add(testEq(uturn[1][1], v(0.5, 0, sqrt(3/4)))).
    r:add(testEq(uturn[2][1], v(-0.5, 0, sqrt(3/4)))).
    r:add(testEq(uturn[2][2]:p, v(0, 0, sqrt(3)))).
    return r.
}

function testTurnPathCCTooFar {
    local r to list().
    local near to turn2d(zeroV, 0.1, zeroR).
    local far to turn2d(unitZ, 0.1, zeroR).
    local fail to turnToTurnCC(near, far).
    r:add(testEq(fail:length(), 0)).
    return r.
}