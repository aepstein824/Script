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

function matchGeoPlane {
    parameter wGeo.

    local sNorm to shipNorm().
    local wPos to wGeo:position - body:position.
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

    matchPlanes(wNorm).
    nodeExecute().

    return wDelayS.
}

function doWaypoint {
    parameter w.

    print "Going for " + w:name.

    matchGeoPlane(w:geoposition).

    planCutAtWaypoint(w).
    nodeExecute().

    waitWarp(time:seconds + nextNode:eta - 60).
    lock steering to nextNode:deltav.
    waitWarpPhsx(time:seconds + nextNode:eta - 10).
    wait until vDot(w:position - ship:position, ship:prograde:vector) < 0.
    doAG13To45Science().
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

function vacDescendToward {
    parameter wGeo.
   
    matchGeoPlane(wGeo).

    local norm to shipNorm().
    local wPos to groundPosition(wGeo).
    local pePos to shipPAtPe().
    local wTanly to vectorAngleAround(pePos, norm, wPos).
    local deorbitAngle to 20.
    local deorbitTanly to mod(wTanly - deorbitAngle + 360, 360).
    // print "wTanly = " + wTanly.
    // print "deorbitTanly = " + deorbitTanly.
    local deorbitDur to timeBetweenTanlies(obt:trueanomaly, deorbitTanly, obt).
    print "deorbitDur " + deorbitDur * sToHours.
    local passoverDur to timeBetweenTanlies(obt:trueanomaly, wTanly, obt).
    print "passoverDur " + passoverDur * sToHours.
    local landDur to 2 * passoverDur - deorbitDur.

    local mm to 360 / obt:period.
    // print "mm " + mm.
    // bodyMm is right handed
    local bodyMm to -body:angularvel:y * constant:radtodeg.
    // print "bdmm " + bodyMm.
    // positive norm and bodymm mean body is moving in same direction, deorbit later
    local timeFactor to (mm + bodyMm * norm:y) / mm.
    // print "timeFactor " + timeFactor.
    set deorbitDur to deorbitDur. // * timeFactor.
    local p2 to rotateVecAround(wPos, v(0, 1, 0), bodyMm * landDur).
    
    local deorbitTime to time + deorbitDur.
    local res to lambertLanding(ship, p2, deorbitTime).
    add res:burnNode.
    nodeExecute().
}

function vacLand {
    legs on.
    suicideBurn(600).
    suicideBurn(100).
    coast(5).
}

function vacClimb {
    parameter height.
    verticalLeapTo(100).
    lock steering to heading(90, 45, 0).
    lock throttle to 1.
    until apoapsis > height {
        nodeStage().
        wait 0.
    }
    lock throttle to 0.
    wait 1.
}