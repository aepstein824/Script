@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

function optimizeFixedWalk {
    parameter f, combine, success, start, dspace.
    parameter tries to 500.

    local point to start.
    for i in range(tries) {
        local dX to v(dspace, 0, 0).
        local dY to v(0, dspace, 0).
        local dFdSpace to v(
            (f(combine(point, dX)) - f(combine(point, -dX))) / 2 / dspace,
            (f(combine(point, dY)) - f(combine(point, -dY))) / 2 / dspace, 0).
        if success(dFdSpace) {
            print " Success with dFdSpace of " + vecRound(dFdSpace, 4).
            break.
        } else {
            local walk to -1 * dspace * dFdSpace:normalized.
            set point to combine(point, walk).
        }
        if i = tries - 1 {
            print " Fixed walk optimizer gave up at " + vecRound(dFdSpace, 4).
        }
    }
    return point.
}

function optimizeNewtonSolve {
    parameter fAndD, x0, eps to 1e-10.

    local tries to 10.
    local x to x0.
    for k in range(tries) {
        local yAndD to fAndD(x).
        local y to yAndD[0].
        local dy_dx to yAndD[1].
        if abs(y) < eps {
            break.
        }
        if abs(dy_dx) < 1e-12 {
            print "Aborting since dy_dx = " + dy_dx.
            break.
        }
        set x to x - y / dy_dx.
    }
    return x.
}
