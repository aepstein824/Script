@LAZYGLOBAL OFF.

function tanlyToEanlyR {
    parameter argOrbit.
    parameter tanly.
    local e to argOrbit:eccentricity.

    local quad1 to arcCos((e + cos(tanly)) / (1 + e * cos(tanly))).
    if tanly > 180 {
        return 360 - quad1.
    }
    return quad1.
}

function eanlyToManlyR {
    parameter argOrbit.
    parameter eanly.
    local e to argOrbit:eccentricity.
    
    return eanly - e * sin(eanly) * constant:radtodeg.
}

function manlyToEanlyR {
    parameter argOrbit.
    parameter manly.
    local e to argOrbit:eccentricity.

    local e0 to manly.
    local ei to e0.
    from {local i is 0.} until i = 10 step {set i to i + 1.} do {
        local fi to ei - e * sin(ei) * constant:radtodeg - manly.
        local di to 1 - e * cos(ei).
        print fi + " -- " + di.
        set ei to ei - (fi / di).
    }

    return ei.
}

function eanlyToTanlyR {
    parameter argOrbit.
    parameter eanly.
    local e to argOrbit:eccentricity.

    local quad1 to arccos((cos(eanly) - e) / (1 - e * cos(eanly))).
    if eanly > quad1 {
        return 360 - quad1.
    }
    return quad1.
}

function tanlyToEanly {
    parameter argOrbit.
    parameter tanly.
    local e to argOrbit:eccentricity.

    local quad1 to arcCos((e + cos(tanly)) / (1 + e * cos(tanly))).
    if tanly > 180 {
        return 360 - quad1.
    }
    return quad1.
}

function eanlyToManly {
    parameter argOrbit.
    parameter eanly.
    local e to argOrbit:eccentricity.
    
    return eanly - e * sin(eanly) * constant:radtodeg.
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

    local manlyX to eanlyToManly(argOrbit, tanlyToEanly(argOrbit, x)).
    local manlyY to eanlyToManly(argOrbit, tanlyToEanly(argOrbit, y)).

    if x > y {
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
    local orbX to removeComp(p2, norm).
    // print "orbX " + orbx.
    local angleToO to vectorAngleAround(p1, norm, orbX).

    return posmod(angleToO + o:trueanomaly, 360).
}