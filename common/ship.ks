@LAZYGLOBAL OFF.

function shipNorm {
    return vCrs(ship:prograde:vector, ship:position - body:position):normalized.
}

function shipPAt {
    parameter t.
    return positionAt(ship, t) - body:position.
}

function shipPAtPe {
    return shipPAt(obt:eta:periapsis + time).
}

function shipVAt {
    parameter t.
    return velocityAt(ship, t):orbit.
}