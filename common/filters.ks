@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

function differCreate {
    parameter initValues, t.

    local derivatives to list().

    for val in initValues {
        // get zero in the correct type
        derivatives:add(val - val).
    }

    return lexicon(
        "Last", initValues,
        "D", derivatives,
        "T", t
    ).
}

function differUpdate {
    parameter differ, newValues, t.

    local dt to max(t - differ:T, 0.02).
    local oldValues to differ:Last.
    local derivatives to list().

    for i in range(newValues:length) {
        local new to newValues[i].
        local old to oldValues[i].
        derivatives:add((new - old) / dt).
    }

    set differ:Last to newValues.
    set differ:T to t.
    set differ:D to derivatives.

    return derivatives.
}

function stepLowpassUpdate {
    parameter val, newval, k.
    return (1 - k) * val + k * newval.
}

function linearRegressionCreate {
    parameter maxPoints.

    return lex(
        "maxPoints", maxPoints,
        "x", queue(),
        "y", queue(),
        "sumX", 0,
        "sumY", 0,
        "sumX2", 0,
        "sumXY", 0,
        "m", 0,
        "b", 0
    ).
}

function linearRegressionUpdate {
    parameter linReg, newX, newY.

    linReg:x:push(newX).
    linReg:y:push(newY).

    set linReg:sumX to linReg:sumX + newX.
    set linReg:sumY to linReg:sumY + newY.
    set linReg:sumX2 to linReg:sumX2 + newX ^ 2.
    set linReg:sumXY to linReg:sumXY + newX * newY.

    if linReg:x:length() > linReg:maxPoints {
        local oldX to linReg:x:pop().
        local oldY to linReg:y:pop().

        set linReg:sumX to linReg:sumX - oldX.
        set linReg:sumY to linReg:sumY - oldY.
        set linReg:sumX2 to linReg:sumX2 - oldX ^ 2.
        set linReg:sumXY to linReg:sumXY - oldX * oldY.
    }

    local count to linReg:x:length().
    if count < 2 {
        return.
    }
    set linReg:m to (
        (count * linReg:sumXY - linReg:sumX * linReg:sumY)
        / (count * linReg:sumX2 - linReg:sumX ^ 2)
    ).
    set linReg:b to (linReg:sumY - linReg:m * linReg:sumX) / count.
}

function meanCreate {
    parameter lim.
    return lex(
        "y", 0,
        "count", 0,
        "lim", lim
    ).
}

function meanUpdate {
    parameter mean, x.

    local count to min(mean:count, mean:lim - 1).
    local newY to (x + mean:y * count) / (count + 1).
    set mean:y to newY.
    set mean:count to count + 1.
}