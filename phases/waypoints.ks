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
    until false {
        for w in allWaypoints() {
            if w:body = body and not w:grounded {
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
        if minInc <> 360 {
            doWaypoint(minW).
            set minInc to 360.
        } else {
            break.
        }
    }
}

function doWaypoint {
    parameter w.

    print "Going for " + w:name.

    local sNorm to shipNorm().
    local wPos to w:position - body:position.
    local over to vCrs(wPos, sNorm).
    local wNorm to vCrs(over, wPos):normalized.
    local orbW to removeComp(wPos, sNorm).
    local pePos to shipPAtPe().

    // estimate travel time in current orbits
    local wTanlyS to vectorAngleAround(pePos, sNorm, orbW).
    local wDelayS to timeBetweenTanlies(obt:trueanomaly, wTanlyS, obt).
    // -1 for left handed rotation, right handed curls.
    set wNorm to rotateVecAround(wNorm, v(0, 1, 0), 
        -1 * wDelayS * body:angularvel:y * constant:radtodeg).

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
    local ratio to rw / ra.
    local reversal to 1.
    if ratio > 1 {
        set ratio to 1 / ratio.
        set reversal to -1.
    }
    local cutAngle to arcCos(ratio).

    local cutTanly to mod(wTanly - cutAngle + 360, 360).
    local cutTime to timeBetweenTanlies(obt:trueanomaly, cutTanly, obt) + time.
    local gravityFudge to 0.7.
    local startV to shipVAt(cutTime):mag.
    local radBurn to -gravityFudge * startV * sin(cutAngle / 2) * reversal.

    local wTime to timeBetweenTanlies(cutTanly, wTanly, obt) + cutTime.

    add node(cutTime, radBurn, 0, 0).
    add node(wTime + 5, -1 * radBurn, 0, 0).
}