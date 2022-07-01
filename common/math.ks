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
    return sin(x * 57.2958).
}

function cosR {
    parameter x.
    return cos(x * 57.2958).
}

function tanR {
    parameter x.
    return tan(x * 57.2958).
}

function arcCosR {
    parameter x.
    return arcCos(x) * 0.017453.
}

function arcTanR {
    parameter x.
    return arctan(x) * 0.017453.
}

function arcTan2R {
    parameter x, y.
    return arcTan2(x, y) * 0.017453.
}

function vectorAngleR {
    parameter x, y.
    return vang(x, y) * 0.017453.
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

function rotateVecAround {
    parameter vec, upRef, x.
    local across to vCrs(vec, upRef).
    return vec * cos(x) + across * sin(x).
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
    set orth to orth:normalized.
    return x - vDot(x, orth) * orth.
}

function clamp {
    parameter x, low, high.
    return max(min(x, high), low).
}

function quadraticFormula {
    parameter a, b, c, sign.

    return (-b + sign * sqrt(b^2 - 4 * a * c)) / 2 / a.
}

function qfMax {
    parameter a, b, c.
    local p to quadraticFormula(a, b, c, 1).
    local m to quadraticFormula(a, b, c, -1).
    return max(p, m).
}

function posmod {
    parameter dividend, divisor.
    local badmod to mod(dividend, divisor).
    if dividend < 0 {
        return divisor + badmod.
    }
    return badmod.
}

