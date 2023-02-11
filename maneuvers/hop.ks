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

    print " Leap to " + h.
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
    parameter targetAlt to -10000.
    parameter finalV to 5.
    set finalV to max(finalV, 1).

    controlLock().

    local riseTime to verticalSpeed / gat(altitude).

    if riseTime > 10 {
        set kuniverse:timewarp:warp to 1.
    }

    print " Rising".
    wait until verticalSpeed < -1.

    print " Falling".
    until false {
        local hTgt to altitude - targetAlt.
        local terrainH to terrainHAt(ship:position).
        local hSafe to altitude - terrainH - safeH.
        // print "hTgt " + round(hTgt) + ", hSafe " + round(hSafe).
        local h0 to min(hTgt, hSafe).
        local centripetal to (groundspeed ^ 2 / (body:radius + altitude) / 4).
        local g to gat(terrainH) - centripetal.
        local v0 to verticalSpeed.

        local vertRatio to abs(v0 / velocity:surface:mag).
        local thrustAccel to ship:maxthrust / ship:mass.
        local twrRatio to (thrustAccel - g) / thrustAccel.
        local tb to shipTimeToDV(velocity:surface:mag - finalV) 
            / vertRatio / twrRatio.

        local a to vertRatio * ship:maxThrust / ship:mass - g.
        local finalH to h0 + v0 * tb + 0.5 * a * (tb ^ 2).
        // print "finalH " + round(finalH) + ", " + round(tb).

        local srfRetro to -1 * ship:velocity:surface.
        set controlSteer to srfRetro.
        if finalH > 2000 {
            set kuniverse:timewarp:warp to 2.
        } else if finalH > 1000 {
            set kuniverse:timewarp:warp to 1.
        } else { 
            kuniverse:timewarp:cancelwarp().
        }
        if finalH < 0 {
            break.
        } 

        set controlThrot to 0.

        wait 0.1.
    }

    enableRcs().

    // TODO replace with real equation solving
    local startV to ship:velocity:surface.
    local currentV to startV.

    print " Burn!".
    until currentV:mag < finalV {
        set currentV to ship:velocity:surface.
        set controlSteer to -currentV.
        set controlThrot to 1.
        wait 0.
    }
    print " Finished Burn".

    disableRcs().

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
    until ship:status = "LANDED" or ship:status = "SPLASHED" {
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
    lock steering to lookDirUp(up:forevector, facing:upvector).
    lock throttle to 0.
    wait 5.
}

function groundPosition {
    parameter geo, height to 0.

    local terrainH to geo:terrainHeight + height.
    return geo:altitudePosition(terrainH) - body:position.
}

function spinPos {
    parameter pos, dur.
    local bodyMm to -body:angularvel:y * constant:radtodeg.
    local spun to rotateVecAround(pos, unitY, bodyMm * dur).
    return spun.
}