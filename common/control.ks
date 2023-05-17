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

function thrustAlpha {
    parameter thrustState, now, nowThrot.

    local differ to thrustState:differ.
    differUpdate(differ, list(nowThrot), now).
    local firstD to differ:D[0].
    local cmdThrot to thrustState:throt.
    local diffThrot to cmdThrot - nowThrot.
    if abs(diffThrot) < .1 {
        return.
    }
    local curAlpha to firstD / diffThrot.
    local alphaEstimator to thrustState:meanUp.
    if diffThrot < 0 {
        set alphaEstimator to thrustState:meanDown.
    }
    meanUpdate(alphaEstimator, curAlpha).
}

function thrustUpdate {
    parameter thrustState, now, nowThrot, goalThrot.

    thrustAlpha(thrustState, now, nowThrot).

    set goalThrot to clamp(goalThrot, 0, 1).
    local alphaEstimator to thrustState:meanUp.
    local edgeThrot to 1.
    if goalThrot < nowThrot {
        set alphaEstimator to thrustState:meanDown.
        set edgeThrot to 0.
    }
    local alpha to alphaEstimator:y.

    local dThrot to alpha * (edgeThrot - goalThrot).
    local dThrotTime to dThrot * 1.
    local throtError to goalThrot - nowThrot.
    if alpha < 0.01 or abs(dThrotTime) > abs(throtError) {
        set thrustState:throt to goalThrot.
    } else {
        set thrustState:throt to edgeThrot.
    }
}

function thrustPromiseForGoal {
    parameter thrustState, nowThrot, goalThrot.

    // Note that the goalThrot being queried might be different from the
    // goalThrot used in the update.

    set goalThrot to clamp(goalThrot, 0, 1).
    local alphaEstimator to thrustState:meanUp.
    local edgeThrot to 1.
    local goalMNow to goalThrot - nowThrot.
    if goalMNow < 0 {
        set alphaEstimator to thrustState:meanDown.
        set edgeThrot to 0.
    }
    local alpha to alphaEstimator:y.
    if alpha < 0.01 {
        return 0.
    }

    if abs(goalMNow) < 0.03 {
        // too small to even bother calculating simple and hard
        return 0.
    }

    local simpleTerm to -goalMNow / alpha.

    local nowMEdge to nowThrot - edgeThrot.
    local goalMEdge to goalThrot - edgeThrot.
    local hardTerm to 0.
    // I don't want to mess with NaN or rounding errors when term is small
    if abs(nowMedge) > 0.03 and abs(goalMEdge) > 0.01 {
        set hardTerm to goalMEdge * ln(goalMEdge / nowMEdge) / alpha.
    }

    // print "alpha " + round(alpha, 2) 
        // + " promise " + round(simpleTerm, 2) + " + " + round(hardTerm, 2).
        // + " promise " + round(simpleTerm + hardTerm, 2).
    return simpleTerm + hardTerm.
}
