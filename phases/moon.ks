@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/lambert.ks").

function doMoonFlyby {
    parameter dest.

    print "Go to " + dest:name.
    local hl to hlIntercept(ship, dest).
    local arrivalTime to time:seconds + hl:when + hl:duration.
    add hl:burnNode.
    nodeExecute().
    wait 5.
    if not orbit:hasnextpatch() or orbit:nextpatch:body <> dest{
        print "Correcting Course".
        // Time after escape.
        local arrivalEta to arrivalTime - time:seconds.
        local dt to .05 * arrivalEta.
        local startTime to time:seconds + dt * kIntercept:StartSpan + 5 * 60.
        local correction to lambertGrid(ship, minmus, startTime, arrivalEta, dt, dt).
        add correction:burnNode.
        nodeExecute().
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
    wait 10.
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

