@LAZYGLOBAL OFF.

runOncePath("0:common/geo.ks").
runOncePath("0:maneuvers/flight.ks").

global kAirline to lexicon().
set kAirline:DiffToVspd to 1.0 / 30.
set kAirline:MaxTurnAngle to 30.
set kAirline:TurnR to 0.1.

function airlineCruiseVspd {
    parameter tgtAlt, curAlt, lim.
    local vDiff to tgtAlt - curAlt.
    return clamp(vDiff * kAirline:DiffToVspd, -lim, lim).
}

function airlineTurnError {
    parameter turn, pos2d, v2d.
    local posC to pos2d - turn:p.
    local radDiff to posC:mag - turn:r.
    local inside to radDiff < 0.
    local posO to posC.
    if inside {
        set posO to posC:normalized * (turn:r - radDiff). 
    }
    local posO2d to posO + turn:p.
    local tgt2d to turnIntersectPoint(turn, posO2d).
    local error to vectorAngleAround(v2d, unitY, tgt2d - posO2d).
    if inside {
        set error to -1 * error.
    }
    return smallAng(error).
}

function airlineTurnErrorToXacc {
    parameter error, dimlessR, turnXacc, ccw.

    local errorX to clamp(-error / kAirline:MaxTurnAngle, -1, 1). 

    local rDist to dimlessR - 1.
    if rDist < kAirline:TurnR {
        return (choose -1 if ccw else 1) * turnXacc + errorX.
    }
    return errorX * (turnXacc + 1).
}

function airlineStraightErrorToXacc {
    parameter app, apv.
    local closeFactor to lerp(app:z/1000, 0.1, 3).
    local tgtX to closeFactor * apv:z * app:x / app:z.
    local xdiff to tgtX - apv:x.
    return clamp(xdiff, -1, 1).
}