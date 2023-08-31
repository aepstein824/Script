local kRawCount to 10.

function rawCreate {
    return lexicon(
        "angularDiff", differCreate(list(zeroV), time:seconds),
        "angularAcc", linearRegressionCreateVec(kRawCount),
        // "yaw", linearRegressionCreate(kRawCount),
        // "pitch", linearRegressionCreate(kRawCount),
        // "roll", linearRegressionCreate(kRawCount)
        "lowXYZ", zeroV:vec
    ).
}

function rawUpdate {
    parameter raw.

    local aoa to vang(vxcl(facing:rightvector, velocity:surface),
        facing:upvector) - 90.

    local nowAngularVel to constant:radtodeg * (
        facing:inverse * ship:angularvel).
    differUpdate(raw:angularDiff, list(nowAngularVel), time:seconds).

    local nowYPR to ship:control:pilotrotation.
    local nowXYZ to v(
        nowYPR:y - 2 * aoa,
        nowYPR:x,
        nowYPR:z
    ).


    linearRegressionUpdateVec(raw:angularAcc,
        nowXYZ / aoa, raw:angularDiff:D[0]).
    // print vecround(raw:angularDiff:D[0], 2).
    // print choose 0 if lowXYZ:x = 0 else 
    //     raw:angularDiff:D[0]:x / lowXYZ:x / aoa.
    // print choose 0 if lowXYZ:x = 0 else 
    //     nowAngularVel:x / lowXYZ:x.
    // print nowXYZ:x.

    local controlNoise to  .02 * sin(360 * mod(time:seconds / 4, 1)) * v(1, 1, 1).

    print vecround(vecMultiplyComps(
        -1 * raw:angularAcc:m,
        vecInvertComps(raw:angularAcc:b)
    ), 4).

    // set ship:control:rotation to vecMultiplyComps(
    //     -1 * raw:angularAcc:m,
    //     vecInvertComps(raw:angularAcc:b)
    // ) + controlNoise.
    // set ship:control:rotation to controlNoise.

    // print raw:angularAcc:m.
}

local raw to rawCreate().
until false {
    // if ship:control:pilotrotation:y > 0.5 {
    //     set ship:control:neutralize to true.
    //     break.
    // }
    rawUpdate(raw).
    wait 0.
}

function linearRegressionCreateVec {
    parameter maxPoints.

    return lex(
        "maxPoints", maxPoints,
        "x", queue(),
        "y", queue(),
        "sumX", zeroV:vec,
        "sumY", zeroV:vec,
        "sumX2", zeroV:vec,
        "sumXY", zeroV:vec,
        "m", zeroV:vec,
        "b", zeroV:vec
    ).
}

function linearRegressionUpdateVec {
    parameter linReg, newX, newY.

    linReg:x:push(newX).
    linReg:y:push(newY).

    set linReg:sumX to linReg:sumX + newX.
    set linReg:sumY to linReg:sumY + newY.
    set linReg:sumX2 to linReg:sumX2 + vecSqrComps(newX).
    set linReg:sumXY to linReg:sumXY + vecMultiplyComps(newX, newY).

    if linReg:x:length() > linReg:maxPoints {
        local oldX to linReg:x:pop().
        local oldY to linReg:y:pop().

        set linReg:sumX to linReg:sumX - oldX.
        set linReg:sumY to linReg:sumY - oldY.
        set linReg:sumX2 to linReg:sumX2 - vecSqrComps(oldX).
        set linReg:sumXY to linReg:sumXY - vecMultiplyComps(oldX, oldY).
    }

    local count to linReg:x:length().
    if count < 2 {
        return.
    }
    set linReg:m to vecMultiplyComps(
        (count * linReg:sumXY - vecMultiplyComps(linReg:sumX, linReg:sumY)),
        vecInvertComps(count * linReg:sumX2 - vecSqrComps(linReg:sumX2))).
    set linReg:b to (linReg:sumY - vecMultiplyComps(linReg:m, linReg:sumX))
        / count.
}
