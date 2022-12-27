@LAZYGLOBAL OFF.

runOncePath("0:common/bins").
runOncePath("0:/test/test_utils").

local twoCell to list(0).
local threeCell to list(0, 1).
local velocities to list(50, 100, 150).
local angles to list(0, 1, 2).

local flightData to list( 
    v(20, 0.1, 10),
    v(60, 0.1, 11),
    v(170, 0.1, 13),
    v(20, 1.1, 110),
    v(60, 1.1, 111),
    v(170, 1.1, 113),
    v(20, 2.1, 210),
    v(60, 2.1, 211),
    v(170, 2.1, 213)
).

local tests to lexicon(
    "testIndices", testIndices@,
    "testGetSet", testGetSet@,
    "testRow", testRow@
).

testRun(tests).

function testIndices {
    local r to list().
    local row to twoCell.
    r:add(testEq(binsKeyToIndex(row, -1), 0)).
    r:add(testEq(binsKeyToIndex(row, 1), 1)).
    set row to threeCell.
    r:add(testEq(binsKeyToIndex(row, -1), 0)).
    r:add(testEq(binsKeyToIndex(row, 0.5), 1)).
    r:add(testEq(binsKeyToIndex(row, 2), 2)).
    set row to velocities.
    r:add(testEq(binsKeyToIndex(row, 20), 0)).
    r:add(testEq(binsKeyToIndex(row, 80), 1)).
    r:add(testEq(binsKeyToIndex(row, 350), 3)).
    return r.
 }

function testGetSet {
    local r to list().
    local sut to binsCreate(velocities, angles).
    local slow to v(0, 0.2, 5).
    binsSet(sut, slow).
    r:add(testEq(binsGetPoint(sut, v(10, 0.3, 0)), slow)).
    local fast to v(70, 4, 500).
    binsSet(sut, fast).
    r:add(testEq(binsGetPoint(sut, v(69, 2.1, 0)), fast)).
    for d in flightData {
        binsSet(sut, d).
        r:add(testEq(binsGetPoint(sut, d), d)).
    }
    local p1 to flightDataP1().
    for d in p1 {
        binsSet(sut, d).
        r:add(testEq(binsGetPoint(sut, d), d)).
    }
    return r.
}

function testRow {
    local r to list().
    return r.
}

function flightDataP1 {
    local p1 to list().
    for d in flightData {
        p1:add(v(d:x, d:y, d:z + 1)).
    }
    return p1.
}