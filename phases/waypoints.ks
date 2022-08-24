@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/orbit.ks").

global kWaypointsClimbAngle to 23.

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

function waitForRotation {
    parameter wGeo.

    local norm to shipNorm().
    local spinningNorm to removeComp(norm, cosmicNorth).
    local wPos to wGeo:position - body:position.
    local spinningPos to removeComp(wPos, cosmicNorth).

    local bodyRadSpd to body:angularvel:y.
    local waitRad to vectorAngleAroundR(spinningPos, -sgn(bodyRadSpd) * cosmicNorth, 
        spinningNorm).
    if waitRad > constant:pi {
        set waitRad to waitRad - constant:pi / 2.
    } else {
        set waitRad to waitRad + constant:pi / 2.
    }
    local waitDur to waitRad / abs(bodyRadSpd).
    set waitDur to posmod(waitDur - orbit:period / 2, 2 * constant:pi / bodyRadSpd).
    waitWarp(waitDur + time).
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

    if abs(obt:inclination) > 45 {
        waitForRotation(wGeo).
    }

    local r to periapsis + body:radius.
    local a to r * 1.05 / 2.
    local ecc to r / a - 1.
    // print "ecc " + ecc.
    local landR to body:radius + wGeo:terrainHeight.
    local cosTanly to ((a / landR) * (1 - ecc ^ 2) - 1) / ecc.
    // print "cosTanly " + cosTanly.
    local tanly to arcCos(cosTanly).
    // print "tanly " + tanly.

    local eanly to arcCos((ecc + cosTanly) / (1 + ecc * cosTanly)).
    local manly to eanly - ecc * sin(eanly).
    local mm to constant:radtodeg * sqrt(body:mu / a ^ 3).
    local landDur to (180 - manly) / mm.
    local planeDur to (tanly - 90) * obt:period / 360.
    local postDur to planeDur + landDur.
    // print "post burn time " + postTime * sToHours + "h".

    local norm to shipNorm().
    local bodyMm to -body:angularvel:y * constant:radtodeg.
    local wPosNow to groundPosition(wGeo).

    local early to detimestamp(time + 30).
    local late to detimestamp(early + obt:period).
    local mid to 0.
    local burnPos to ship:position.
    local wPosMid to wPosNow.
    for i in range(12) {
        set mid to (early + late) / 2.
        local landTimeMid to mid + postDur.
        local nowTillLand to landTimeMid - time:seconds.
        set wPosMid to rotateVecAround(wPosNow, cosmicNorth, bodyMm * nowTillLand).
        set burnPos to vCrs(norm, wPosMid).
        local burnTanly to posToTanly(burnPos + body:position, obt).
        local burnTime to timeBetweenTanlies(obt:trueanomaly, burnTanly, obt).
        // print "Off by " + (burnTime + time - mid):seconds.
        if burnTime + time < mid {
            set late to mid.
        } else {
            set early to mid.
        }
        // clearVecDraws().
        // vecdraw(body:position, wPosMid * 2, red, "body", 1, true).
        // vecdraw(body:position, burnPos * 2, blue, "an", 1, true).
    }

    local dt to 90 - vectorAngleAround(wPosMid, burnPos, norm).
    print dt.
    local burnStartSpd to shipVAt(mid):mag.
    local dv to 2 * burnStartSpd * sin(dt / 2).
    add node(mid, 0, dv * cos(dt / 2), -dv * sin(dt / 2)).
    nodeExecute().

    set wPosNow to groundPosition(wGeo).
    local wPosLand to rotateVecAround(wPosNow, cosmicNorth, bodyMm * postDur).
    local deorbitTime to time + planeDur.
    local res to lambertLanding(ship, wPosLand, deorbitTime).
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
    parameter compass to 90.
    verticalLeapTo(120).
    lock steering to heading(compass, kWaypointsClimbAngle, 0).
    lock throttle to 1.
    until apoapsis > height {
        nodeStage().
        wait 0.
    }
    lock throttle to 0.
    wait 1.
}