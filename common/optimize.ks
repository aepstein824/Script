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