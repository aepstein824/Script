@LAZYGLOBAL OFF.

runOncePath("0:common/control.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

// verticalLeapTo(200).
// wait until ship:velocity:surface:mag < 2.
// hopBestTo(waypoint("ksc"):geoposition:altitudeposition(150)).
// suicideBurn(150).
// coast(12).

function gHere {
    local g to body:mu / (groundAlt() + body:radius) ^ 2.
    return g.
}

function hop45To {
    parameter pos.
    local dPos to pos - ship:position.
    local hDir to -body:position:normalized.
    local xVec to removeComp(dPos, hDir).
    local dh to vDot(dPos, hDir).
    local dx to xVec:mag.
    local g to gHere().
    
    local hopDir to (hDir + xVec:normalized):normalized.
    local spd to sqrt(g * dx ^ 2 / (dx - dh)).
    print spd.
    lock throttle to 1.
    lock steering to hopDir.
    wait until vDot(hopDir, ship:velocity:surface) > spd.
    lock throttle to 0.
}

function hopBestTo {
    parameter pos.
    local dPos to pos - ship:position.
    local hDir to -body:position:normalized.
    local xVec to removeComp(dPos, hDir).
    local dh to vDot(dPos, hDir).
    local dx to xVec:mag.
    local g to gHere().
    print "x " + dx.
    print "h " + dh.
    print "g " + g.
    local p to (g * dx / 2).
    local q to (dh / dx).
    local l0 to (p ^ 2 / (q ^ 2 + 1)) ^ (1/4). 
    local v0 to p / l0 + q * l0.
    print "(" + l0 + ", " + v0+ ")".
    local burnVec to l0 * xVec:normalized + v0 * hDir.
    
    local hopDir to burnVec:normalized.
    local spd to burnVec:mag.
    print spd.
    lock throttle to 1.
    lock steering to hopDir.
    wait until vDot(hopDir, ship:velocity:surface) > spd.
    lock throttle to 0.
}


function verticalLeapTo {
    parameter h.

    controlLock().

    if (h < groundAlt()) {
        return.
    }

    print "Leap to " + h.
    local g to body:mu / (groundAlt() + body:radius) ^ 2.

    local v0 to 1000000000.
    until ship:velocity:surface:mag > v0 {
        set v0 to sqrt(2 * (h - groundAlt()) * g).

        set controlSteer to lookDirUp(-body:position, v(0, 1, 0)).
        set controlThrot to 1.
    }


    set controlThrot to 0.

    wait until groundAlt() > .90 * h.

    controlUnlock().
}

function suicideBurn {
    parameter safeH.
    parameter finalV to 5.

    controlLock().

    set kuniverse:timewarp:mode to "PHYSICS".
    set kuniverse:timewarp:rate to 4.

    print "Rising".
    wait until vDot(body:position, ship:velocity:surface) > 1.

    print "Falling".
    until false {
        local terrainH to terrainHAt(ship:position).
        local h0 to altitude - terrainH - safeH.
        local g to body:mu / (groundAlt() + body:radius) ^ 2.
        local down to -body:position:normalized.
        local v0 to vDot(down, ship:velocity:surface).
        local vs to removeComp(ship:velocity:surface, down).

        // time for doing nothing
        local na to -0.5 * g.
        local nb to v0.
        local nc to h0.
        local tn to qfMax(na, nb, nc).
        local spdN to abs(v0 - g * tn).
        local spdTotal to sqrt(spdN ^ 2 + vs:mag ^ 2).
        local a to (spdN / spdTotal) * ship:maxThrust / ship:mass - g.

        local thBurn to terrainHAt(ship:position + ship:velocity:orbit * tn).
        if thBurn > terrainH {
            set h0 to altitude - terrainH - safeH.
        }

        local qa to -0.5 * g * (1 + 1 / a).
        local qb to v0 * (1 + 1 / a).
        local qc to h0 - 0.5 * v0^2 / a.
        local tf to qfMax(qa, qb, qc).

        if tf < 5 {
            kuniverse:timewarp:cancelwarp().
        }
        if tf < 0 {
            break.
        } 

        set controlSteer to -1 * ship:velocity:surface.
        set controlThrot to 0.

        wait 0.1.
    }

    local startV to -1 * ship:velocity:surface.
    local currentV to startV.

    print "Burn!".
    until vDot(startV:normalized, currentV) < finalV {
        set currentV to -1 * ship:velocity:surface.
        set controlSteer to currentV:normalized().
        set controlThrot to max(currentV:mag / 5, 0.5).
        wait 0.
    }

    controlUnlock().
}

function coast {
    parameter spd.

    local kp to -1 / (ship:maxthrust / ship:mass).
    // print "kp = " + kp.
    local ki to -.04.
    // local ki to 0.
    local kd to -.002.
    // local kd to 0.
    local pid to pidloop(kp, ki, kd).
    set pid:setpoint to spd.
    local throt to 0.
    lock throttle to throt.

    lock steering to -(0.1 * ship:velocity:surface:normalized 
        + body:position:normalized).
    until ship:status = "LANDED"  or ship:status = "SPLASHED" {
        local vDown to vDot(body:position:normalized, ship:velocity:surface).
        set throt to pid:update(time:seconds, vDown).
        set throt to clamp(throt, 0, 1).
        if throt <= 0.01 {
            pid:reset().
        }
        local scaredAlt to groundAlt() / 3.
        if spd > scaredAlt {
            set pid:setpoint to min(scaredAlt, 2).
        }
        wait 0.
    }
    lock steering to up.
    lock throttle to 0.
    wait 5.
}

function groundPosition {
    parameter geo, height to 0.

    local terrainH to geo:terrainHeight + height.
    return geo:altitudePosition(terrainH) - body:position.
}

// attempt 1
        // local ePot to g * (groundAlt() - safeH).
        // local v to ship:velocity:surface.
        // local down to body:position:normalized.
        // local vDown0 to vDot(down, v).
        // local vDown to sqrt(2 * (.5 * vDown0 ^ 2 + ePot)).
        // local vHori to removeComp(v, down).
        // local vBurn to (vDown * down + vHori).
        // local maxA to ship:maxThrust / ship:mass - g * (vDown / vBurn:mag).
        
        // local burnDur to vBurn:mag / maxA.
        // // fallH is negative to represent fall.
        // local fallH to safeH - groundAlt().
        // local pmTerm to sqrt(vDown0 ^ 2 - 2 * g * fallH).
        // local numerator to -vDown0 + pmTerm.
        // local fallDur to numerator / g.
        // // print burnDur + ", " + fallDur + ", " + vDo
