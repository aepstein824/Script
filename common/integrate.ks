@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

function proBurnRk4 {
    parameter mu, p0, v0, m0, thrustKn, drain, dur.
    parameter dt to 0.1.
    
    // Simulate a slow burn prograde for a given duration using rk4

    local origin to kerbin:position.
    local arrow to vecdraw(
        origin,
        p0,
        red
    ).
    set arrow:show to true.

    local muNeg to -1 * mu.
    local p to p0.
    local vel to v0.
    local m to m0.
    local elapsed to 0.
    local dtHalf to dt / 2 .
    until elapsed >= dur - dtHalf {
        local lastLoop to false.
        local remaining to dur - elapsed.
        if remaining < dt {
            set dt to remaining.
            set lastLoop to true.
        }
        // in integration, y = position and velocity concatenated
        local grav1 to muNeg * p:normalized / (p:mag ^ 2).
        local thrustVec to vel:normalized * thrustKn.
        local dv1 to (grav1 + thrustVec / m).
        // dp1 is vel

        // halftime pos/mass is easy to calculate
        local mHalf to m - dtHalf * drain.
        local mNext to m - dt * drain.
        // we get k2 from doing euler at half timestep from y1
        local p2 to p + dtHalf * vel.
        local grav2 to muNeg * p2:normalized / (p2:mag ^ 2).
        local dp2 to vel + dtHalf * dv1.
        local dv2 to (grav2 + thrustVec / mHalf).
        // we get k3 from adding k2 to y1 for a half timestep
        local p3 to p + dtHalf * dp2.
        local grav3 to muNeg * p3:normalized / (p3:mag ^ 2).
        local dp3 to vel + dtHalf * dv2.
        local dv3 to (grav3 + thrustVec / mHalf).
        // we get k4 from adding k3 to y1 for a full timestep
        local p4 to p + dt * dp3.
        local grav4 to muNeg * p4:normalized / (p4:mag ^ 2).
        local dp4 to vel + dt * dv3.
        local dv4 to (grav4 + thrustVec / mNext).

        local dp to (vel + 2 * dp2 + 2 * dp3 + dp4) / 6.
        local dv to (dv1 + 2 * dv2 + 2 * dv3 + dv4) / 6.

        set m to mNext.
        set p to p + dt * dp.
        set vel to vel + dt * dv.
        set elapsed to elapsed + dt.
        set arrow:start to kerbin:position.
        set arrow:vec to p.
        if lastLoop {
            break.
        }
    }
    set arrow:show to false.
    return lexicon("p", p, "v", vel, "m", m).
}

function proBurnEuler {
    parameter mu, p0, v0, m0, thrustKn, drain, dur.
    parameter dt to 0.1.

    // Simulate a slow burn prograde for a given duration using euler's method

    local muNeg to -1 * mu.
    local p to p0.
    local vel to v0.
    local m to m0.
    local elapsed to 0.
    until false {
        local lastLoop to false.
        local remaining to dur - elapsed.
        if remaining < dt {
            set dt to remaining.
            set lastLoop to true.
        }
        local accGrav to muNeg * p / (p:mag ^ 3).
        local accThrust to vel:normalized * thrustKn / m.
        local dv to accGrav + accThrust.
        set p   to p   + dt * vel + dt ^ 2 * (accGrav + accThrust / 2).
        set vel to vel + dt * dv.
        set m   to m   - dt * drain.
        set elapsed to elapsed + dt.
        if lastLoop {
            break.
        }
    }
    return lexicon("p", p, "v", vel, "m", m).
}