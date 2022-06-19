@LAZYGLOBAL OFF.

function sgn {
    parameter x.
    if x >= 0 {
        return 1.
    }
    return 0.
}

function sinR {
    parameter x.
    return sin(x * constant:RadToDeg).
}

function cosR {
    parameter x.
    return cos(x * constant:RadToDeg).
}

function tanR {
    parameter x.
    return tan(x * constant:RadToDeg).
}

function arcCosR {
    parameter x.
    return arcCos(x) * constant:DegToRad.
}

function arcTanR {
    parameter x.
    return arctan(x) * constant:DegToRad.
}

function arcTan2R {
    parameter x, y.
    return arcTan2(x, y) * constant:DegToRad.
}

function vectorAngleR {
    parameter x, y.
    return vang(x, y) * constant:DegToRad.
}

function vectorAngleAround {
    parameter base, upRef, x.
    local ang to vang(base, x).
    if vDot(x, vCrs(base, upRef)) < 0 {
        return 360 - ang.
    }
    return ang.
}

function vectorAngleAroundR {
    parameter base, upRef, x.
    local ang to vectorAngleR(base, x).
    if vDot(x, vCrs(base, upRef)) < 0 {
        return 2 * constant:pi - ang.
    }
    return ang.
}

function invLerp {
    parameter x, lower, upper.
    local diff to upper - lower.
    if diff = 0 {
        return 1.
    }
    return min((x - lower) / diff, 1).
}

function removeComp {
    parameter x, orth.
    return x - vDot(x, orth) * orth.
}
