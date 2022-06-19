@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/orbit.ks").


function doWaypoints {
    local minInc to 360.
    local minW to false.
    for w in allWaypoints() {
        if w:body = body {
            local sNorm to shipNorm().
            local p1 to w:position - body:position.
            local over to vCrs(p1, sNorm).
            local wNorm to vCrs(over, p1).
            local ang to vAng(wNorm, sNorm).
            if ang < minInc {
                set minInc to ang.
                set minW to w.
            }
        }
    }
    if minW <> false {
        doWaypoint(minW).
    }
}

function doWaypoint {
    parameter w.

    local sNorm to shipNorm().
    local p1 to w:position - body:position.
    local over to vCrs(p1, sNorm).
    local wNorm to vCrs(over, p1):normalized.
    matchPlanesAndSemi(wNorm, kWarpHeights[body]).
    nodeExecute().

    planCutAtWaypoint(w).
    nodeExecute().

    waitWarp(time:seconds + nextNode:eta - 60).
    lock steering to nextNode:deltav.
    waitWarpPhsx(time:seconds + nextNode:eta - 10).
    wait until vDot(w:position - ship:position, ship:prograde:vector) < 0.
    doScience().
    nodeExecute().

    circleNextExec(kWarpHeights[body]).
}

function planCutAtWaypoint {
    parameter w.
    local norm to shipNorm().
    local orbW to removeComp(w:position - body:position, norm).
    local pePos to shipPAtPe().
    local wTanly to vectorAngleAround(pePos, norm, orbW).

    local ra to obt:apoapsis + body:radius.
    local rw to w:altitude + body:radius.
    local cutAngle to arcCos(rw / ra).

    local cutTanly to mod(wTanly - cutAngle + 360, 360).
    local cutTime to timeBetweenTanlies(obt:trueanomaly, cutTanly, obt) + time.
    local gravityFudge to 0.7.
    local startV to shipVAt(cutTime):mag.
    local radBurn to -gravityFudge * startV * sin(cutAngle / 2).


    local wTime to timeBetweenTanlies(cutTanly, wTanly, obt) + cutTime.

    add node(cutTime, radBurn, 0, 0).
    add node(wTime + 5, -1 * radBurn, 0, 0).
}