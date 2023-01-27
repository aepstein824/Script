@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

function tanlyToEanly {
    parameter ecc.
    parameter tanly.

    local quad1 to arcCos((ecc + cos(tanly)) / (1 + ecc * cos(tanly))).
    if tanly > 180 {
        return 360 - quad1.
    }
    return quad1.
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

function orbitalRelativeV {
    parameter obtable1, obtable2, t.
    local p1 to positionAt(obtable1, t).
    local p2 to positionAt(obtable2, t).
    local oneToTwo to p2 - p1.
    local v1 to velocityAt(obtable1, t):orbit.
    local v2 to velocityAt(obtable2, t):orbit.
    local vDiff to v1 - v2.
    local relV to vdot(vDiff, oneToTwo:normalized).
    return relV.
}

function closestApproachNear {
    parameter obtable1, obtable2, t.

    local lr to .1.
    set t to time + obt:eta:periapsis.
    local eps to 3.
    local signLast to 0.
    // use gradient descent, lowering learning rate when crossing the min
    until false {
        local relV to orbitalRelativeV(obtable1, obtable2, t).
        local u to lr * relV.
        set t to t + u.

        // print "Iter:".
        // print " d = " + relV.
        // print " x = " + distanceAt(obtable1, obtable2, t).
        // print " u = " + u.

        local signNow to sgn(relV).
        if signNow * signLast = -1 {
            set lr to lr / 2.
        }
        set signLast to signNow.

        if abs(u) < 0.01 {
            break.
        }
        if abs(relV) < eps {
            break.
        }
    }
    return t.
}

function closestApproach {
    parameter obtable1, obtable2.

    local bestDistance to 10^20.
    local bestTime to time:seconds.
    local bigPeriod to max(obtable1:obt:period, obtable2:obt:period).
    local count to 36.

    for i in range(count) {
        local t to (i / count) * bigPeriod + time:seconds.
        local nearDist to distanceAt(obtable1, obtable2, t).
        if nearDist < bestDistance {
            set bestDistance to nearDist.
            set bestTime to t.
        }
    }

    return closestApproachNear(obtable1, obtable2, bestTime).
}


// acceleration
function gat {
    parameter h.

    return body:mu / (body:radius + h) ^ 2. 
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