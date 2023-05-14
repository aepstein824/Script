@LAZYGLOBAL OFF.

runOncePath("0:common/geo.ks").
runOncePath("0:test/test_utils.ks").

local tests to lexicon(
    "northFrame", testNorth@,
    "approach", testApproach@,
    "headingTo", testHeadingTo@,
    "north2dToGeo", testNorth2dToGeo@,
    "beacon", testBeacon@,
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
    "turnTooFar", testTurnPathCCTooFar@,
    "turnPointToPoint", testTurnPointToPoint@
).

testRun(tests).

function testNorth {
    local t to list().
    local shipNorth to geoNorthFrame(ship:geoposition).
    local headNorth to heading(0, 0).
    t:add(testEq(shipNorth:forevector, headNorth:forevector)).
    t:add(testEq(shipNorth:upvector, headNorth:upvector)).
    local geo0 to latlng(0, 0).
    local north0 to geoNorthFrame(geo0).
    t:add(testEq(north0:forevector, unitY)).
    local geo1 to latlng(45, 0).
    local north1 to geoNorthFrame(geo1).
    local rot1 to rotateVecAround(unitY, north0:rightvector, -45).
    t:add(testEq(north1:forevector, rot1)).
    return t.
}

function testApproach {
    local t to list().
    local geo0 to latlng(10, 10).
    local approachGeo00 to geoApproach(geo0, 0, 1000).
    t:add(testGr(approachGeo00:lat, geo0:lat)).
    t:add(testEq(approachGeo00:lng, geo0:lng)).
    local approachGeo09 to geoApproach(geo0, 90, 1000).
    t:add(testEq(approachGeo09:lat, geo0:lat)).
    t:add(testGr(approachGeo09:lng, geo0:lng)).
    return t.
}

function testHeadingTo {
    local t to list().
    local geo0 to latlng(80, 10).
    local hdg00 to geoHeadingTo(geo0, latlng(80, 189)). // slightly above 0
    local hdg09 to geoHeadingTo(geo0, latlng(80, 10.1)).
    local hdg18 to geoHeadingTo(geo0, latlng(-10, 10)).
    local hdg27 to geoHeadingTo(geo0, latlng(80, 9.9)).
    t:add(testEq(hdg00, 0, 1)).
    t:add(testEq(hdg09, 90, 1)).
    t:add(testEq(hdg18, 180, 1)).
    t:add(testEq(hdg27, 270, 1)).
    return t.
}

function testNorth2dToGeo {
    local t to list().
    local geoNp to latlng(89.99, 0).
    local dist to 30000.
    local frame to geoNorthFrame(geoNp).
    local pos05 to dist * v( 1, 0,  1):normalized.
    local pos14 to dist * v( 1, 0, -1):normalized.
    local pos23 to dist * v(-1, 0, -1):normalized.
    local pos32 to dist * v(-1, 0,  1):normalized.

    local geo05 to geoNorth2dToGeo(geoNp, frame, pos05).
    local geo14 to geoNorth2dToGeo(geoNp, frame, pos14).
    local geo23 to geoNorth2dToGeo(geoNp, frame, pos23).
    local geo32 to geoNorth2dToGeo(geoNp, frame, pos32).

    t:add(testEq(geoHeadingTo(geoNp, geo05),  45, 1)).
    t:add(testEq(geoHeadingTo(geoNp, geo14), 135, 1)).
    t:add(testEq(geoHeadingTo(geoNp, geo23), 225, 1)).
    t:add(testEq(geoHeadingTo(geoNp, geo32), 315, 1)).
    t:add(testEq(geoBodyPosDistance(geoNp:position, geo05:position), dist, 1)).
    t:add(testEq(geoBodyPosDistance(geoNp:position, geo14:position), dist, 1)).
    t:add(testEq(geoBodyPosDistance(geoNp:position, geo23:position), dist, 1)).
    t:add(testEq(geoBodyPosDistance(geoNp:position, geo32:position), dist, 1)).
    return t.
}

function testBeacon {
    local t to list().
    local geoCenter to latlng(0, 0).
    local geo00 to latlng(90, 0).
    local geo09 to latlng(0, 90).
    local geo18 to latlng(-90, 0).
    local geo27 to latlng(0, -90).
    t:add(testEq(geoBeacon(geoCenter, 0), geo00)).
    t:add(testEq(geoBeacon(geoCenter, 90), geo09)).
    t:add(testEq(geoBeacon(geoCenter, 180), geo18)).
    t:add(testEq(geoBeacon(geoCenter, 270), geo27)).
    return t.
}

function testTurnCircles {
    local t to list().
    local right to turnFromPoint(zeroV, zeroR, 10, 1). 
    t:add(testEq(right:p, v(10, 0, 0))).
    t:add(testEq(right:d:forevector, v(0, 0, 1))).
    t:add(testEq(right:d:upvector, v(0, -1, 0))).
    t:add(testEq(right:d:rightvector, v(-1, 0, 0))).
    t:add(testEq(turnOut(right), zeroV)).
    local left to turnFromPoint(zeroV, zeroR, 10, -1). 
    t:add(testEq(left:p, v(-10, 0, 0))).
    t:add(testEq(left:d:forevector, v(0, 0, 1))).
    t:add(testEq(left:d:upvector, v(0, 1, 0))).
    t:add(testEq(left:d:rightvector, v(1, 0, 0))).
    t:add(testEq(turnOut(left), zeroV)).
    return t.
}

function testTurnIntersectVec {
    local t to list().
    local og to unitZ.
    local testRCircle to turn2d(og, 1, zeroR).
    t:add(testEq(turnIntersectVec(testRCircle, unitZ), og + unitX)).
    t:add(testEq(turnIntersectVec(testRCircle, unitX), zeroV)).
    t:add(testEq(turnIntersectVec(testRCircle, 50 * unitX), zeroV)).
    local testLCircle to turn2d(og, 1, r(0, 0, 180)).
    t:add(testEq(turnIntersectVec(testLCircle, unitZ), og - unitX)).
    t:add(testEq(turnIntersectVec(testLCircle, unitX), 2 * unitZ)).
    return t.
}

function testTurnIntersectPoint {
    local t to list().
    local og to unitZ.
    local testRCircle to turn2d(og, 2, zeroR).
    local cornerXZ to 2 * unitX + 2 * unitZ + og.
    local cornerXMZ to 2 * unitX - 2 * unitZ + og.
    t:add(testEq(turnIntersectPoint(testRCircle, cornerXZ), og + 2 * unitZ)).
    t:add(testEq(turnIntersectPoint(testRCircle, cornerXMZ), og + 2 * unitX)).
    local testLCircle to turn2d(og, 2, r(0, 0, 180)).
    t:add(testEq(turnIntersectPoint(testLCircle, cornerXZ), og + 2 * unitX)).
    t:add(testEq(turnIntersectPoint(testLCircle, cornerXMZ), og - 2 * unitZ)).
    return t.
}

function testTurnPathLLSimple {
   local t to list().
   local left0 to turn2d(v(1,0,5), 1, leftR).
   local left1 to turn2d(v(1,0,0), 1, leftR).
   local pth to turnToTurn(left0, left1).
   t:add(testEq(pth[0][0], "start")).
   t:add(testEq(pth[0][1], v(0, 0, 5))).
   t:add(testEq(pth[1][0], "turn")).
   t:add(testEq(pth[1][1], v(2, 0, 5))).
   t:add(testEq(pth[2][0], "straight")).
   t:add(testEq(pth[2][1], v(2, 0, 0))).
   t:add(testEq(pth[3][0], "turn")).
   t:add(testEq(pth[3][1], v(0, 0, 0))).
   t:add(testEq(turnPathDistance(pth), 5 + 2 * constant:pi)).
   return t.
}

function testTurnPathRRSimple {
   local t to list().
   local right0 to turn2d(v(1,0,5), 1, zeroR).
   local right1 to turn2d(v(1,0,0), 1, zeroR).
   local pth to turnToTurn(right0, right1).
   t:add(testEq(pth[0][0], "start")).
   t:add(testEq(pth[0][1], v(2, 0, 5))).
   t:add(testEq(pth[1][0], "turn")).
   t:add(testEq(pth[1][1], v(0, 0, 5))).
   t:add(testEq(pth[2][0], "straight")).
   t:add(testEq(pth[2][1], v(0, 0, 0))).
   t:add(testEq(pth[3][0], "turn")).
   t:add(testEq(pth[3][1], v(2, 0, 0))).
   return t.
}

function testTurnPathLRSimple {
   local t to list().
   local left0 to turn2d(v(-1,0,5), 1, leftR).
   local right1 to turn2d(v(1,0,0), 1, zeroR).
   local pth to turnToTurn(left0, right1).
   t:add(testEq(pth[0][0], "start")).
   t:add(testEq(pth[0][1], v(-2, 0, 5))).
   t:add(testEq(pth[1][0], "turn")).
   t:add(testEq(pth[1][1], v(0, 0, 5))).
   t:add(testEq(pth[2][0], "straight")).
   t:add(testEq(pth[2][1], v(0, 0, 0))).
   t:add(testEq(pth[3][0], "turn")).
   t:add(testEq(pth[3][1], v(2, 0, 0))).
   return t.
}

function testTurnPathRLSimple {
   local t to list().
   local right0 to turn2d(v(1,0,5), 1, zeroR).
   local left1 to turn2d(v(-1,0,0), 1, leftR).
   local pth to turnToTurn(right0, left1).
   t:add(testEq(pth[0][0], "start")).
   t:add(testEq(pth[0][1], v(2, 0, 5))).
   t:add(testEq(pth[1][0], "turn")).
   t:add(testEq(pth[1][1], v(0, 0, 5))).
   t:add(testEq(pth[2][0], "straight")).
   t:add(testEq(pth[2][1], v(0, 0, 0))).
   t:add(testEq(pth[3][0], "turn")).
   t:add(testEq(pth[3][1], v(-2, 0, 0))).
   return t.
}

function testTurnDrafted {
    local t to list().

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
    t:add(testEq(albr, v(0, 0, 12), 0.5)).
    local arcl to turnToTurn(ar, cl)[2][1].
    t:add(testEq(arcl, v(8, 0, 10.5), 0.5)).
    local aldr to turnToTurn(al, dr)[2][1].
    t:add(testEq(aldr, v(2.5, 0, 4.5), 0.5)).
    local arel to turnToTurn(ar, el)[2][1].
    t:add(testEq(arel, v(6, 0, 2), 0.5)).

    // check src positions from B
    local brar to turnToTurn(br, ar)[1][1].
    t:add(testEq(brar, v(0.5, 0, 10), 0.5)).
    local blcl to turnToTurn(bl, cl)[1][1].
    t:add(testEq(blcl, v(0.5, 0, 12), 0.5)).
    local bldl to turnToTurn(bl, dl)[1][1].
    t:add(testEq(bldl, v(1, 0, 11.5), 0.5)).
    local blel to turnToTurn(bl, el)[1][1].
    t:add(testEq(blel, v(1, 0, 11.5), 0.5)).

    // check dst positions from C, except A
    local crar to turnToTurn(cr, ar)[1][1].
    t:add(testEq(crar, v(8.5, 0, 10.5), 0.5)).
    local clbr to turnToTurn(cl, br)[2][1].
    t:add(testEq(clbr, v(1, 0, 11.5), 0.5)).
    local cldr to turnToTurn(cl, dr)[2][1].
    t:add(testEq(cldr, v(3, 0, 5), 0.5)).
    local crer to turnToTurn(cr, er)[2][1].
    t:add(testEq(crer, v(2, 0, 2.5), 0.5)).

    // check src positions from D
    local drar to turnToTurn(dr, ar)[1][1].
    t:add(testEq(drar, v(4, 0, 4), 0.5)).
    local dlbl to turnToTurn(dl, bl)[1][1].
    t:add(testEq(dlbl, v(2, 0, 3.5), 0.5)).
    local drcr to turnToTurn(dr, cr)[1][1].
    t:add(testEq(drcr, v(3.5, 0, 3), 0.5)).
    local drer to turnToTurn(dr, er)[1][1].
    t:add(testEq(drer, v(2, 0, 4), 0.5)).

    // check dst positions from E
    local elar to turnToTurn(el, ar)[2][1].
    t:add(testEq(elar, v(6, 0, 12), 0.5)).
    local elbr to turnToTurn(el, br)[2][1].
    t:add(testEq(elbr, v(1, 0, 11), 0.5)).
    local elcr to turnToTurn(el, cr)[2][1].
    t:add(testEq(elcr, v(8, 0, 5), 0.5)).
    local eldl to turnToTurn(el, dl)[2][1].
    t:add(testEq(eldl, v(2, 0, 4), 0.5)).

    return t.
}

function testTurnPathLRLSimple {
    local t to list().
    local start to turn2d(-unitX, 1, zeroR).
    local end to turn2d(unitX, 1, zeroR).
    local uturn to turnToTurnCC(start, end).
    t:add(testEq(uturn[1][1], v(-0.5, 0, sqrt(3/4)))).
    t:add(testEq(uturn[2][1], v(0.5, 0, sqrt(3/4)))).
    t:add(testEq(uturn[2][2]:p, v(0, 0, sqrt(3)))).
    return t.
}

function testTurnPathRLRSimple {
    local t to list().
    local start to turn2d(unitX, 1, leftR).
    local end to turn2d(-unitX, 1, leftR).
    local uturn to turnToTurnCC(start, end).
    t:add(testEq(uturn[1][1], v(0.5, 0, sqrt(3/4)))).
    t:add(testEq(uturn[2][1], v(-0.5, 0, sqrt(3/4)))).
    t:add(testEq(uturn[2][2]:p, v(0, 0, sqrt(3)))).
    return t.
}

function testTurnPathCCTooFar {
    local t to list().
    local near to turn2d(zeroV, 0.1, zeroR).
    local far to turn2d(unitZ, 0.1, zeroR).
    local fail to turnToTurnCC(near, far).
    t:add(testEq(fail:length(), 0)).
    return t.
}

function testTurnPointToPoint {
    local t to list().
    local pth to list().


    set pth to turnPointToPoint(v(-0.0001,0,5), 1, leftR, v(0,0,0), 1, leftR).
    t:add(testEq(pth[0][0], "start")).
    t:add(testEq(pth[0][1], v(0, 0, 5))).
    t:add(testEq(pth[1][0], "turn")).
    t:add(testEq(pth[1][1], v(2, 0, 5))).
    t:add(testEq(pth[2][0], "straight")).
    t:add(testEq(pth[2][1], v(2, 0, 0))).
    t:add(testEq(pth[3][0], "turn")).
    t:add(testEq(pth[3][1], v(0, 0, 0))).
    t:add(testEq(turnPathDistance(pth), 5 + 2 * constant:pi)).

    set pth to turnPointToPoint(v(2,0,5), 1, zeroR, v(-2,0,0), 1, leftR).
    t:add(testEq(pth[0][0], "start")).
    t:add(testEq(pth[0][1], v(2, 0, 5))).
    t:add(testEq(pth[1][0], "turn")).
    t:add(testEq(pth[1][1], v(0, 0, 5))).
    t:add(testEq(pth[2][0], "straight")).
    t:add(testEq(pth[2][1], v(0, 0, 0))).
    t:add(testEq(pth[3][0], "turn")).
    t:add(testEq(pth[3][1], v(-2, 0, 0))).

    local start to turn2d(unitX, 1, leftR).
    local end to turn2d(-unitX, 1, leftR).
    local uturn to turnToTurnCC(start, end).
    set pth to turnPointToPoint(zeroV, 1, zeroR, zeroV, 1, r(0, 180, 0)).
    t:add(testEq(uturn[1][1], v(0.5, 0, sqrt(3/4)))).
    t:add(testEq(uturn[2][1], v(-0.5, 0, sqrt(3/4)))).
    t:add(testEq(uturn[2][2]:p, v(0, 0, sqrt(3)))).
    return t.
}
