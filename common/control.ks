@LAZYGLOBAL OFF.

runOncePath("0:common/filters.ks").

global controlSteer to facing.
global controlThrot to 0.
global controlLocked to false.

function controlLock {
    sas off.
    set controlLocked to true.
    set controlSteer to facing.
    set controlThrot to 0.
    lock steering to controlSteer.
    lock throttle to controlThrot.
}

function controlUnlock {
    set controlLocked to false.
    unlock steering.
    unlock throttle.
}

function controlMaybeLock {
    if controlLocked = false {
        set controlLocked to true.
        lock steering to controlSteer.
        lock throttle to controlThrot.
    }
}

function controlMaybeUnlock {
    if controlLocked = true {
        set controlLocked to false.
        unlock steering.
        unlock throttle.
    }
}

function thrustCreate {
    return lex(
        "meanUp", meanCreate(10),
        "meanDown", meanCreate(10),
        "throt", 0,
        "differ", differCreate(list(0), time:seconds)
    ).
}

function thrustUpdate {
    parameter thrustState, now, maxiThrust, curThrust, tgtThrust.

    if maxiThrust = 0 {
        return.
    }

    local differ to thrustState:differ.
    differUpdate(differ, list(curThrust), now).

    local curThrot to curThrust / maxiThrust.
    local diffThrot to thrustState:throt - curThrot.
    local firstD to differ:D[0].
    local curAlpha to firstD / diffThrot.

    local alphaEstimator to thrustState:meanUp.
    local edgeThrot to 1.
    if diffThrot < 0 {
        set alphaEstimator to thrustState:meanDown.
        set edgeThrot to 0.
    }

    local goalThrot to tgtThrust / maxiThrust.

    if abs(diffThrot) < 1 {
        set thrustState:throt to goalThrot.
        return.
    }

    meanUpdate(alphaEstimator, curAlpha).
    local alpha to alphaEstimator:y.

    local dThrot to alpha * (edgeThrot - curThrot).
    if abs(dThrot * 0.05) > abs(goalThrot - curThrot) {
        set thrustState:throt to goalThrot.
    } else {
        set thrustState:throt to edgeThrot.
    }
}