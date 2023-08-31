@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/optimize.ks").

function tanlyToEanly {
    parameter ecc.
    parameter tanly.

    local eanly to arctan2(sqrt(1 - ecc ^ 2) * sin(tanly), ecc + cos(tanly)).
    if tanly > 180 {
        set eanly to eanly + 360.
    }
    return eanly.
}

function eanlyToManly {
    parameter ecc.
    parameter eanly.
    
    return eanly - ecc * sin(eanly) * constant:radtodeg.
}

function manlyToEanly {
    parameter argOrbit.
    parameter manly.
    local e to argOrbit:eccentricity.

    local e0 to manly.
    local ei to e0.
    from {local i is 0.} until i = 10 step {set i to i + 1.} do {
        local fi to ei - e * sin(ei) * constant:radtodeg - manly.
        local di to 1 - e * cos(ei).
        set ei to ei - (fi / di).
    }

    return ei.
}

function eanlyToTanly {
    parameter argOrbit.
    parameter eanly.
    local e to argOrbit:eccentricity.

    local quad1 to arccos((cos(eanly) - e) / (1 - e * cos(eanly))).
    if eanly > quad1 {
        return 360 - quad1.
    }
    return quad1.
}

function timeBetweenTanlies {
    parameter x, y, argOrbit.

    set x to posmod(x, 360).
    set y to posmod(y, 360).

    local ecc to argOrbit:eccentricity.
    local manlyX to eanlyToManly(ecc, tanlyToEanly(ecc, x)).
    local manlyY to eanlyToManly(ecc, tanlyToEanly(ecc, y)).

    if manlyX > manlyY {
        set manlyX to manlyX - 360.
    }
    // print manlyX + ", " + manlyY.

    local avgAngularV to 360 / argOrbit:period.
    return (manlyY - manlyX) / avgAngularV. 
}

function posToTanly {
    parameter x, o.

    local p1 to o:position - o:body:position.
    local p2 to x - o:body:position.
    // print "p2 " + p2.
    local norm to vCrs(o:velocity:orbit, p1):normalized. 
    // print "norm " + norm.
    local orbX to vxcl(norm, p2).
    // print "orbX " + orbx.
    local angleToO to vectorAngleAround(p1, norm, orbX).

    return posmod(angleToO + o:trueanomaly, 360).
}

function obtRadiusToTanly {
    parameter radius, o.

    // solve r = a * (1 - e^2) / (1 + e * cos(tanly)) for tanly

    local semi to o:semimajoraxis.
    local ecc to o:eccentricity.
    local cosTanly to (semi * (1 - ecc ^ 2) - radius) / radius / ecc.
    // this will always return the positive angle
    return arcCos(cosTanly).
}

function obtRadiusToDuration {
    parameter radius, o.

    local tanlySmall to obtRadiusToTanly(radius, o).
    local tanlyLarge to 360 - tanlySmall.
    local tanlyNow to o:trueanomaly.
    local timeSmall to timeBetweenTanlies(tanlyNow, tanlySmall, o).
    local timeLarge to timeBetweenTanlies(tanlyNow, tanlyLarge, o).
    return min(timeSmall, timeLarge).
}

function circleToSemiV {
    parameter r1, r2, mu.
    local circleV to sqrt(mu / r1).
    local a to (r1 + r2) / 2. 
    local semiV to sqrt((mu / a) * (r2 / r1)).
    return semiV - circleV.
}

function distanceAt {
    parameter obtable1, obtable2, t.

    local p1 to positionAt(obtable1, t).
    local p2 to positionAt(obtable2, t).
    local x to (p2 - p1):mag.
    return x.
}

function normOf {
    parameter obt1.
    return vCrs(obt1:velocity:orbit, 
        obt1:position - obt1:body:position):normalized.
}

function obtRnpFromPV {
    parameter pos, vel.
    return lookDirUp(vel, pos) * r(0, 0, 90).
}

function obtRelativeV {
    parameter obtable1, obtable2, t.
    local p1 to positionAt(obtable1, t).
    local p2 to positionAt(obtable2, t).
    local oneToTwo to p2 - p1.
    local v1 to velocityAt(obtable1, t):orbit.
    local v2 to velocityAt(obtable2, t):orbit.
    local vDiff to v1 - v2.
    local relV to removeComp(vDiff, oneToTwo:normalized):mag.
    return relV.
}

function closestApproachNear {
    parameter obtable1, obtable2, t.

    return optimizeNewtonSolve({
        parameter x0.
        return funcAndDeriv({
            parameter x1.
            return obtRelativeV(obtable1, obtable2, x1).
        }, x0).
    }, t).
}

function closestApproach {
    parameter obtable1, obtable2.

    local bestDistance to 10^20.
    local bestTime to time:seconds.
    local relPeriod to orbitalRelativePeriod(obtable1:obt:period,
        obtable2:obt:period).
    local count to 36.

    for i in range(count) {
        local t to (i / count) * relPeriod + time:seconds.
        local nearTime to closestApproachNear(obtable1, obtable2, bestTime).
        local nearDist to distanceAt(obtable1, obtable2, nearTime).
        if nearDist < bestDistance {
            set bestDistance to nearDist.
            set bestTime to t.
        }
    }
    local durTill to bestTime - time:seconds.
    set durTill to posMod(durTill, relPeriod).
    set bestTime to time:seconds + durTill.
    print " Closest approach distance " + round(bestDistance)
        + " at " + timeRoundStr(bestTime - time:seconds).
    return bestTime.
}


// acceleration
function gat {
    parameter h.

    return body:mu / (body:radius + h) ^ 2. 
}

function centrip {
    parameter spd, h.

    return spd ^ 2 / (body:radius + h).
}

function orbitalRelativePeriod {
    parameter period1, period2.

    local maxPeriod to 10 * max(period1, period2).
    return 1 / max(1 / maxPeriod, abs(1 / period1 - 1 / period2)).
}

function orbitalSpeed {
    parameter mu, semimajor, radius.

    return sqrt(mu * (2 / radius - 1 / semimajor)).
}

function orbitalPeriodToSemi {
    parameter mu, period.
    return (mu * (period / 2 / constant:pi) ^ 2) ^ (1 / 3).
}

function orbitalSemiToPeriod {
    parameter mu, semi.
    return 2 * constant:pi * sqrt(semi ^ 3 / mu).
}

function bestNorm {
    local tNorm to normOf(target).
    local ourPos to -body:position.
    local inPlane to removeComp(tNorm, ourPos):normalized.
    return inPlane.
}

function launchHeading {
    local norm to bestNorm().
    local pos to -body:position.
    local launchDir to vCrs(pos, norm).
    // vecdraw(body:position, norm:normalized * 2 * body:radius, rgb(0, 0, 1), 
    //     "p1", 1.0, true).
    // vecdraw(body:position, launchDir:normalized * 2 * body:radius, rgb(0, 1, 0),
    //     "p2", 1.0, true).

    local headingAngle to vectorAngleAround(launchDir, pos, v(0, 1, 0)).
    return headingAngle.
}

function waitForTargetPlane {
    parameter planeOf.

    local norm to normOf(planeOf).
    local spinningNorm to removeComp(norm, cosmicNorth).
    local planetPos to shipPAt(time).
    local spinningPos to removeComp(planetPos, cosmicNorth).

    // Check that we actually intersect the plane of target
    local launchInc to vang(unitY, planetPos) - 90.
    local tgtInc to 90 - abs(90 - planeOf:orbit:inclination).
    if launchInc > tgtInc {
        print " Launch site at ang " + round(launchInc, 2) 
            + " can't launch to " + round(tgtInc, 2).
        return.
    }
    print " Waiting to line up with target".

    local bodyRadSpd to body:angularvel:y.
    local waitRad to vectorAngleAroundR(spinningPos, -sgn(bodyRadSpd) * unitY, 
        spinningNorm).
    if abs(waitRad - constant:pi/2) < 0.1 or abs(waitRad - 3*constant:pi/2) 
        < 0.1 {
        return.
    }
    if waitRad > constant:pi {
        set waitRad to waitRad - constant:pi / 2.
    } else {
        set waitRad to waitRad + constant:pi / 2.
    }
    local waitDur to waitRad / abs(bodyRadSpd).
    waitWarp(waitDur + time).
}