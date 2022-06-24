@LAZYGLOBAL OFF.

runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/lambert.ks").

local kMunPeLow to 12000.

function planMunFlyby {
    local best to Lexicon().
    set best:totalV to 1000000.
    for i in range(10, 25) {
        for j in list(7, 8, 9) {
            local startTime to time + i * 2 * 60.
            local flightDuration to j * 60 * 60.
            local results to lambert(ship, mun, V(-2 * mun:radius, 0, 0),
                startTime, flightDuration, false).

            if results:ok {
                set results:totalV to results:burnVec:mag. 
                set results:totalV to results:totalV + results:matchVec:mag.
                if results:totalV < best:totalV {
                    set best to results.
                }
            }
        }
    }
    local nd to best["burnNode"].
    add nd.
    for i in range(30) {
        if (nd:obt:nextpatch():periapsis < 0) {
            set nd:prograde to nd:prograde - 0.5.
        } else if (nd:obt:nextpatch():periapsis < kMunPeLow) {
            set nd:prograde to nd:prograde - 0.1.
        } else {
            break.
        }
        if i < 0 { break. } // unused...
    }
}

function refinePe {
    parameter low, high.
    add node(time, 1, 0, 1).
    local proAndOut to nextnode:deltav:normalized.
    if ship:periapsis < low {
        lock steering to proAndOut.
    } else if ship:periapsis > high {
        lock steering to -1 * proAndOut.
    } 
    wait 3.
    until ship:periapsis > low and ship:periapsis < high {
        lock throttle to 0.1.
        nodeStage().
        wait 0.
    }
    lock throttle to 0.
    remove nextNode.
    wait 1.
    return.
}

