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
    if xname = "Lexicon" {
        // only check the keys in y, x can have extra keys
        for k in y:keys {
            if not x:haskey(k) {
                return testError("Missing key " + k).
            }
            local xv to x[k].
            local yv to y[k].

            local valTest to testEq(xv, yv, eps).
            if not valTest:ok {
                return testError("Difference in key " + k
                    + " " + valTest:message).
            }
        }
        return testOk().
    }
    if xname = "List" {
        for i in range(x:length) {
            local valTest to testEq(x[i], y[i], eps).
            if not valTest:ok {
                return testError("Difference in ind " + i
                    + " " + valTest:message).
            }
        }
        return testOk().
    }
    if xname = "GeoCoordinates" {
        local dist to geoBodyPosDistance(x:position, y:position).
        if dist > 1000 * eps {
            return testError("Geocoords dist [" + dist + "] " + errorString).
        }
        return testOk().
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
    return testError("Expected greater, but X (" + x + ") <= Y (" + y + ")").
}

function testLs {
    parameter x, y.
    if x < y {
        return testOk().
    }
    return testError("Expected lesser, but X (" + x + ") >= Y (" + y + ")").
}

function testRun {
    parameter tests.
    clearScreen.

    for t in tests:keys {
        print "Testing " + t.
        local f to tests[t].
        local results to f().
        local i to 0.
        for u in results {
            if not u:ok {
                print " " + i + ": " + u:message.
            }
            set i to i + 1.
        }
    }
}