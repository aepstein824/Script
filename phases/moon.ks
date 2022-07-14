@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/lambert.ks").

function doMoonFlyby {
    parameter dest.

    local offset to v(-150000).

    print "Go to " + dest:name.
    local hl to hlIntercept(ship, dest, offset).
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
        local correction to lambertGrid(ship, minmus, startTime, arrivalEta, dt, dt,
            offset).
        add correction:burnNode.
        nodeExecute().
    }
}