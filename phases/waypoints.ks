@LAZYGLOBAL OFF.

runOncePath("0:common/geo.ks").
runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/optimize.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/hover.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/orbit.ks").

global kWaypointsClimbLeap to 300.
global kWaypointsClimbAngle to 45.
global kWaypointsOverhead to 300.
global kWaypointsCoastSpeed to 5.

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
    doUseOnceScience().
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

    local rPe to periapsis + body:radius.
    // pe of a fraction the body radius
    local a to (rPe + body:radius / 5) / 2.
    local ecc to rPe / a - 1.
    // print "ecc " + ecc.
    local landR to body:radius + wGeo:terrainHeight + kWaypointsOverhead.
    // todo, should prolly calculate ecc from tanly instead
    local cosTanly to ((a / landR) * (1 - ecc ^ 2) - 1) / ecc.
    // print "cosTanly " + cosTanly.
    local tanly to 360 - arcCos(cosTanly).
    // print "tanly " + tanly.

    // find the time to between the landing burn and the landing
    local mm to constant:radtodeg * sqrt(body:mu / a ^ 3).
    local eanly to tanlyToEanly(ecc, tanly).
    local manly to eanlyToManly(ecc, eanly).
    local landDur to (manly - 180) / mm.
    // print "landDur " + landDur.
    // want to plane change 90 degrees before landing, not 90 before ap
    // 90 - (tanly - 180) is the angle traveled before the plane change
    local planeDur to (90 - (tanly - 180)) * obt:period / 360.
    // print "planeDur " + planeDur.
    local postDur to planeDur + landDur.
    // print "post plane burn time " + postDur.

    local norm to shipNorm().
    local bodyMm to -body:angularvel:y * constant:radtodeg.
    local wPosNow to groundPosition(wGeo, kWaypointsOverhead).

    local early to detimestamp(time + 30).
    local late to detimestamp(early + obt:period).
    local mid to 0.
    local burnPos to ship:position.
    local wPosLand to wPosNow.
    for i in range(12) {
        set mid to (early + late) / 2.
        local landTimeMid to mid + postDur.
        local nowTillLand to landTimeMid - time:seconds.
        set wPosLand to rotateVecAround(wPosNow, cosmicNorth,
            bodyMm * nowTillLand).
        // burnPos is where we would want to do the burn
        set burnPos to vCrs(norm, wPosLand).
        // actualPos is where we will actually be at the proposed time
        local actualPos to shipPAt(mid).
        local error to smallAng(vectorAngleAround(burnPos, norm, actualPos)).
        // Since all orbits are faster than all planet rotations, the planet
        // will drag burnPos around slower than actualPos. Therefore, positive
        // error means we should wait a bit.
        // print "Off by " + error.
        if error > 0 {
            set late to mid.
        } else {
            set early to mid.
        }
        // clearVecDraws().
        // vecdraw(body:position, wPosLand * 2, red, "land", 1, true).
        // vecdraw(body:position, burnPos * 2, blue, "an", 1, true).
        // wait 1.
    }

    local dt to 90 - vectorAngleAround(wPosLand, burnPos, norm).
    local burnStartSpd to shipVAt(mid):mag.
    local dv to 2 * burnStartSpd * sin(dt / 2).
    add node(mid, 0, dv * cos(dt / 2), -dv * sin(dt / 2)).
    nodeExecute().

    set wPosNow to groundPosition(wGeo, kWaypointsOverhead).
    set wPosLand to rotateVecAround(wPosNow, cosmicNorth, bodyMm * postDur).
    local deorbitTime to time + planeDur.
    local res to lambertPosOnly(ship, wPosLand, deorbitTime, landDur).
    add res:burnNode.
    nodeExecute().
}

function vacLand {
    legs on.
    suicideBurn(600).
    suicideBurn(100).
    coast(kWaypointsCoastSpeed).
}

function vacLandGeo {
    parameter wGeo, tgt to list().

    local overheadAlt to 500.
    local correctionLen to 90.

    legs on.

    local geoAlt to wGeo:terrainHeight + overheadAlt.
    local geoRadius to geoAlt + body:radius.
    local impactDur to obtRadiusToDuration(geoRadius, orbit).
    local impactTime to time:seconds + impactDur.
    // local correctionDur to impactDur - correctionLen.
    local correctionTime to impactTime - correctionLen.
    print " warping to correction point".
    waitWarp(correctionTime - 10).
    local wOverheadPos to groundPosition(wGeo, overheadAlt).
    local wPosImpact to spinPos(wOverheadPos, correctionLen).
    print " distance from impact " + (wPosImpact + body:position):mag.

    if correctionTime > time:seconds {
        local res to lambertPosOnly(ship, wPosImpact,
            correctionTime, correctionLen).
        add res:burnnode.
        print " executing correction node".
        nodeExecute().
    }

    print " Suicide Burn".
    suicideBurn(20, geoAlt + overheadAlt / 4, 5).

    print " Controlled Descent to target".
    set kuniverse:timewarp:mode to "PHYSICS".
    set kuniverse:timewarp:rate to 3.
    
    lights on.
    local params to hoverDefaultParams().
    set params:tgt to wGeo.
    set params:seek to true.
    set params:crab to false.
    set params:minG to 0.5.
    set params:maxAccelH to 0.4.
    hoverSwitchMode(params, kHover:Hover).
    hoverLock(params).

    until vxcl(body:position, wGeo:position):mag < 5 
        and vdot(body:position:normalized, wGeo:position) < 50 {
        hoverIter(params).
        wait 0.0.
    }

    print " Descending.".
    kuniverse:timewarp:cancelwarp().
    if not tgt:empty {
        local ports to opsPortFindPair(tgt[0]).
        set params:tgt to ports[1].
    }
    hoverSwitchMode(params, kHover:Descend).
    until ship:status = "LANDED"  or ship:status = "SPLASHED" {
        hoverIter(params).
        wait 0.
    }

    print " Tip Prevention".
    lock steering to lookDirUp(up:forevector, facing:upvector).
    lock throttle to 0.
    print " Landing Successful?".
    wait 5.
    lights off.
}

function vacClimb {
    parameter height.
    parameter compass to 90.
    verticalLeapTo(kWaypointsClimbLeap).
    lock steering to heading(compass, kWaypointsClimbAngle, 0).
    lock throttle to 1.
    until apoapsis > height {
        shipStage().
        wait 0.
    }
    lock throttle to 0.
    wait 1.
}

function geoFlatSearch {
    parameter lz, dspace, success, optimizeSgn.

    local function lzF {
        parameter pos.
        return optimizeSgn * pos:terrainHeight.
    }
    local function lzCombine {
        parameter geo, ds.
        set ds to v(ds:x, 0, ds:y).
        local northFrame to geoNorthFrame(geo).
        local pos to geo:position.
        local combined to pos + northFrame * ds.
        local combinedGeo to geo:body:geopositionof(combined).
        return combinedGeo.
    }
    local function lzSuccess {
        parameter df.
        return (abs(df:x) + abs(df:y)) < success.
    }

    return optimizeFixedWalk(lzF@, lzCombine@, lzSuccess@, lz, dspace).
}

function geoNearestFlat {
    parameter lz.
    local dspace to 10.
    local success to 0.15.

    if lz:body:hasOcean() and lz:terrainheight < 0 {
        return lz.
    }

    print " Searching for flat landing site".
    local start to lz:position.
    local top to geoFlatSearch(lz, dspace, success, -1).
    local topClimb to (top:position - start):mag.
    print " Uphill " + geoRoundStr(top) + " : " + round(topClimb, 2).
    local bottom to geoFlatSearch(lz, dspace, success, 1).
    local bottomClimb to (bottom:position - start):mag.
    print " Downhill " + geoRoundStr(bottom) + " : " + round(bottomClimb, 2).

    local refineDS to 2.
    local refineSuccess to 0.01.
    // Prefer top for safer and more efficient landings
    if topClimb < 2 * bottomClimb {
        local refined to geoFlatSearch(top, refineDS, refineSuccess, -1).
        print " Refined " + geoRoundStr(refined).
        return refined.
    }
    local refined to geoFlatSearch(bottom, refineDS, refineSuccess, 1).
    print " Refined " + geoRoundStr(refined).
    return refined.
}