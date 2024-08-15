@LAZYGLOBAL OFF.

global kEul to constant:e.
global kPi to constant:pi.
global zeroV to v(0, 0, 0).
global unitX to v(1, 0, 0).
global unitY to v(0, 1, 0).
global unitZ to v(0, 0, 1).
global zeroR to r(0, 0, 0).
global leftR to r(0, 0, 180).

function safeDen {
    parameter denominator.
    if denominator = 0 {
        return 3.4e38.
    }
    return denominator.
}

function sgn {
    parameter x.
    if x >= 0 {
        return 1.
    }
    return -1.
}

function sinR {
    parameter x.
    return sin(x * 57.2957795131).
}

function cosR {
    parameter x.
    return cos(x * 57.2957795131).
}

function tanR {
    parameter x.
    return tan(x * 57.2957795131).
}

function arcCosR {
    parameter x.
    return arcCos(x) * 0.01745329251.
}

function arcTanR {
    parameter x.
    return arctan(x) * 0.01745329251.
}

function arcTan2R {
    parameter x, y.
    return arcTan2(x, y) * 0.01745329251.
}

function vectorAngleR {
    parameter x, y.
    return vang(x, y) * 0.01745329251.
}

function vectorAngleAround {
    parameter base, upRef, x.
    set base to vxcl(upRef, base).
    set x to vxcl(upRef, x).
    local ang to vang(base, x).
    if vDot(x, vCrs(base, upRef)) < 0 {
        return 360 - ang.
    }
    return ang.
}

function vectorAngleAroundR {
    parameter base, upRef, x.
    return vectorAngleAround(base, upRef, x) * 0.01745329251.
}

function rotateVecAround {
    parameter vec, upRef, x.
    local dir to  angleAxis(-x, upRef).
    return dir * vec.
}

function rotateVecAroundR {
    parameter vec, upRef, x.
    return rotateVecAround(vec, upRef, x * 57.2957795131).
}

function vecAlong {
    parameter vec, along.
    return along:normalized * vDot(vec, along).
}

function removeComp {
    parameter x, orth.
    return vxcl(orth, x).
}

function lerp {
    parameter x, lower, upper.
    local scale to upper - lower.
    local unclamped to x * scale + lower. 
    return clamp(unclamped, lower, upper).
}
function invLerp {
    parameter x, lower, upper.
    local diff to upper - lower.
    if diff = 0 {
        return 1.
    }
    return clamp((x - lower) / diff, 0, 1).
}

function clamp {
    parameter x, low, high.
    return max(min(x, high), low).
}

function clampAbs {
    parameter x, limit.
    return clamp(x, -limit, limit).
}

// Gets a value out of a deadzone.
function unDeadzone {
    parameter x, limit.
    if abs(x) < limit {
        return sgn(x) * limit.
    }
    return x.
}

function quadraticFormula {
    parameter a, b, c, sign.
    local det to b^2 - 4 * a * c.
    if det <= 0 {
        // print "Quadratic det <= 0".
    }
    return (-b + sign * sqrt(abs(det))) / 2 / a.
}

function qfMax {
    parameter a, b, c.
    local p to quadraticFormula(a, b, c, 1).
    local m to quadraticFormula(a, b, c, -1).
    return max(p, m).
}

function quadraticBoth {
    parameter a, b, c.
    local det to b^2 - 4 * a * c.
    if det < 0 {
        return list().
    }
    local left to -b / 2 / a.
    if det = 0 {
        return list(left).
    }
    local right to sqrt(det) / 2 / a.
    return list(left - right, left + right).
}

function quadraticFirstPos {
    parameter quadList.
    if quadList:length = 0 {
        return 0.
    } else if quadList:length = 1 {
        return quadList[0].
    }
    local left to quadList[0].
    local right to quadList[1].
    if left > 0 {
        return left.
    }
    return right.
}

function posmod {
    parameter dividend, divisor.
    local badmod to mod(dividend, divisor).
    if dividend < 0 {
        return badmod + divisor.
    }
    return badmod.
}

function sinHR {
    parameter x.
    return (kEul^x - kEul^(-x)) / 2.
}

function arcCosHR {
    parameter x.
    return ln(x + sqrt(x^2 - 1)).
}

function vecClampMag {
    parameter vec, mag.
    if vec:mag > mag {
        return vec:normalized * mag.
    }
    else {
        return vec.
    }
}

function vecMinMag {
    parameter vec, mag.
    if vec:mag < mag {
        return vec:normalized * mag.
    }
    else {
        return vec.
    }
}

function vecInvertComps {
    parameter vec.
    return v(
        choose 0 if vec:x = 0 else 1.0 / vec:x,
        choose 0 if vec:y = 0 else 1.0 / vec:y,
        choose 0 if vec:z = 0 else 1.0 / vec:z
    ).
}

function vecSqrComps {
    parameter a.
    return v(
        a:x ^ 2,
        a:y ^ 2,
        a:z ^ 2
    ).
}

function vecMultiplyComps {
    parameter a, b.

    return v(
        a:x * b:x,
        a:y * b:y,
        a:z * b:z
    ).
}

function sgnSqrt {
    parameter x.
    return sgn(x) * sqrt(abs(x)).
}

function vecRound {
    parameter a, n to 2.
    return V(round(a:x, n), round(a:y, n), round(a:z, n)).
}

function smallAng {
    parameter x.
    set x to posmod(x, 360).
    if x > 180 {
        set x to x - 360.
    }
    return x.
}

function posAng {
    parameter x.
    return posmod(x, 360).
}

function smoothAccelFunc {
    parameter accel, linearTime, maxV.

    // This function is the result describing a smoothly increasing acceleration
    // for some time, then switching to a constant acceleration.
    // Let j = jerk, a = acceleration, v = spd, x = position, t = time
    // For the first stage
    //  a = j * t
    //  v = 1/2 * j * t^2
    //  x = 1/6 * j * t^3
    // For the second stage
    //  v = A * (t - T) + V 
    //  x = 1/2 * A * (t - T) + V * (t - T) + P
    //  where capital letters are the value when we hit constant acceleration
    // Solve for v in terms of X and you get the equations below

    local linearSpd to linearTime * accel / 2.
    local linearX to (2 / 3) * (linearSpd ^ 2) / accel.
    local jerk to accel / linearTime.
    local linearCoeff to 0.5 * (jerk * 36) ^ (1 / 3).
    local sqrtCoeff to 2 * accel.
    local sqrtOffset to (-1 / 3) * linearSpd ^ 2.

    function func {
        parameter x.

        local absX to abs(x).
        local sgnX to sgn(x).
        local absY to 0.

        if absX < linearX {
            set absY to linearCoeff * (absX ^ (2 / 3)).
        } else {
            set absY to sqrt(sqrtCoeff * absX + sqrtOffset).
        }
        set absY to min(absY, maxV).

        return sgnX * absY.
    }

    return func@.
}

function funcAndDeriv {
    parameter func, x, dx to 1e-4.

    local y to func(x).
    local y_p to func(x + dx).
    local dy_dx to (y_p - y) / dx.

    return list(y, dy_dx).
}

function funcFirstSecondDeriv {
    parameter func, x, dx to 1e-4.

    local y to func(x).
    local y_p to func(x + dx).
    local y_n to func(x - dx).
    // print "x " + x.
    // print "y and yp and yn = " + y + " " + y_p + " " + y_n.
    local dy_dx to (y_p - y) / dx.
    local d2y_dx2 to (y_p - 2 * y + y_n) / dx / dx.

    return list(dy_dx, d2y_dx2).
}

function detimestamp {
    parameter t.

    if t:typename = "TimeStamp" or t:typename = "TimeSpan" {
        return t:seconds.
    }
    return t.
}

function expm1 {
    parameter x.
    local u to kEul ^ x.
    if u = 1.0 {
        return x.
    }
    if (u - 1.0) = -1.0 {
        return -1.0.
    }
    return (u - 1.0) * x / ln(u).
}

function lnp1 {
    parameter x.
    local u to 1.0 + x.
    if u = 1 {
        return x.
    }
    return ln(u) * x / (u - 1).
}

function timeRoundStr {
    parameter seconds.
    local stamp to timestamp(seconds).
    if stamp:seconds < 0 {
        return stamp:full.
    }
    if stamp:year > 1 or stamp:day > 1 {
        local year to stamp:year - 1.
        local day to stamp:day - 1.
        return year + "y " + day + "d".
    } else {
        return stamp:clock.
    }
}
