@LAZYGLOBAL OFF.

function testOk {
    return lexicon("ok", true,
        "message", "").
}

function testError {
    parameter message.
    return lexicon("ok", false,
        "message", message).
}

function testEq {
    parameter x, y, eps to 0.001.
    local xname to x:typename.
    local yname to y:typename.

    local errorString to 
        "X[" + X + ", " + xname + "] " +
        "Y[" + Y + ", " + yname + "]".
    if xname <> yname {
        return testError("Type mismatch " + errorString).
    }
    if xname = "Scalar" {
        local diff to y - x.
        if abs(diff) > eps {
            return testError("Unequal [" + diff + "] " + errorString).
        } else {
            return testOk().
        }
    }
    if xname = "Vector" {
        local diff to y - x.
        if diff:mag > eps {
            return testError("Unequal [" + diff:mag + "] " + errorString).
        } else {
            return testOk().
        }
    }
    if x <> y {
        return testError("Unequal " + errorString).
    }
    return testOk().
}

function testGr {
    parameter x, y.
    if x > y {
        return testOk().
    }
    return testError("Y (" + y + ") >= X (" + x + ")").
}

function testRun {
    parameter tests.

    for t in tests:keys {
        print "Testing " + t.
        local f to tests[t].
        local results to f().
        local i to 0.
        for r in results {
            if not r:ok {
                print " " + i + ": " + r:message.
            }
            set i to i + 1.
        }
    }
}