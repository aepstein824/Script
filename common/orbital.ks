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

function closestApproach {
    parameter obtable1, obtable2.

    local lr to .5.
    local t to time:seconds.
    if obt:eccentricity < 1 {
        set t to t + obt:period.
    }
    local dt to 10.
    local dxSignLast to 0.
    local tEarly to t.
    until false {
        local t_p to t + dt.

        local x to distanceAt(obtable1, obtable2, t).
        local x_p to distanceAt(obtable1, obtable2, t_p).
        
        local dx_dt to (x_p - x) / dt.
        local dxSign to sgn(dx_dt).
        // print "Iter:".
        // print " t = " + t.
        // print " x = " + x.
        // print " d = " + dx_dt.
        // print " u = " + lr * x / dx_dt / 60 / 60.
        if dxSignLast = -1 and dxSign = 1  {
            break.
        }
        set tEarly to t.
        set t to t - lr * x / dx_dt.
        set dxSignLast to dxSign.
    }

    local earlyLateDifference to t - tEarly.
    local tLate to t + earlyLateDifference.
    set tEarly to tEarly - earlyLateDifference.
    until false {
        // print tEarly * sToHours + ", " + (tLate * sToHours).
        local tGuess to (tEarly + tLate) / 2.
        if (tLate - tEarly) < dt {
            print "Binary search range too small.".
            return t.
        }

        local x to distanceAt(obtable1, obtable2, tGuess - dt).
        local x_p to distanceAt(obtable1, obtable2, tGuess).
        local x_p2 to distanceAt(obtable1, obtable2, tGuess + dt).

        local early to x > x_p.
        local straddle to ((x > x_p) <> (x_p > x_p2)).
        if straddle {
            set t to tGuess.
            break.
        }
        if early {
            set tEarly to tGuess.  
        } else {
            set tLate to tGuess.
        }
    }

    return t.
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