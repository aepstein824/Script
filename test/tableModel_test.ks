@LAZYGLOBAL OFF.

runOncePath("0:common/tableModel.ks").
runOncePath("0:test/test_utils.ks").

local axis1 to list(0).
local axis2 to list(-1, 1).

local tests to lexicon(
    "oneCell", testOneCell@,
    "twoCells", testTwoCells@
).
testRun(tests).

function testOneCell {
    local r to list().
    local table to tableCreate(axis1, axis1).
    tableUpdate(table, 0, 0, 1).
    tableUpdate(table, 0, 5, 2).
    r:add(testEq(tableGet(table, 0, 0), 1.5)).
    r:add(testEq(tableGet(table, 1, 0), 1.5)).
    r:add(testEq(tableGet(table, 0, -100), 1.5)).
    return r.
}

function testTwoCells {
    local r to list().
    local table to tableCreate(axis1, axis2).
    tableUpdate(table, 0, -1, 1).
    tableUpdate(table, 0, 1, 2).
    r:add(testEq(tableGet(table, 0, -1), 1)).
    r:add(testEq(tableGet(table, 0, 0), 1.5)).
    r:add(testEq(tableGet(table, 0, 1), 2)).
    tableUpdate(table, 0, 0, 301.5).
    r:add(testEq(tableGet(table, 0, 0), 101.5)).
    return r.
}