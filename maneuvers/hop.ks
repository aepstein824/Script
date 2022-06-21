@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").

// verticalLeapTo(100).
// lock steering to heading(-55, 20).
// lock throttle to 1.
// wait 3.
// lock throttle to 0.
// suicideBurn(100).
// coast(12).

function groundAlt {
    local ground to altitude - geoPosition:terrainheight.
    if body:hasocean() {
        set ground to max(ground, 0).
    }
    return ground.
}

function terrainHAt {
    parameter p.
    local ground to body:geopositionof(p):terrainheight.
    if body:hasOcean() {
        set ground to max(ground, 0).
    }
    return ground.
}

function verticalLeapTo {
    parameter h.

    if (h < groundAlt()) {
        return.
    }

    print "Leap to " + h.

    local g to body:mu / (groundAlt() + body:radius) ^ 2.
    local v0 to sqrt(2 * (h - groundAlt()) * g).

    lock steering to lookDirUp(-body:position, v(0, 1, 0)).
    lock throttle to 1.

    wait until ship:velocity:surface:mag > v0.

    lock throttle to 0.

    wait until groundAlt() > .95 * h.
}

function suicideBurn {
    parameter safeH.


    print "Rising".
    wait until vDot(body:position, ship:velocity:surface) > 1.

    print "Falling".
    until false {
        set kuniverse:timewarp:mode to "PHYSICS".
        set kuniverse:timewarp:rate to 4.
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

        if tf < 0 {
            kuniverse:timewarp:cancelwarp().
            break.
        } 

        lock steering to -1 * ship:velocity:surface.
        lock throttle to 0.

        wait 0.
    }

    print "Burn!".
    until vDot(body:position, ship:velocity:surface) < 1 {
        // local downLimit to invLerp(vBurn:mag, 0, maxA).
        // lock steering to -vBurn * downLimit + (1 - downLimit)*(up:forevector).
        lock steering to -1 * ship:velocity:surface.
        lock throttle to 1.
    }
}

function coast {
    parameter spd.

    local g to body:mu / (groundAlt() + body:radius) ^ 2.
    local kp to -1 / (ship:maxthrust / ship:mass - g).
    local ki to -.02.
    local kd to -.02.
    local pid to pidloop(kp, ki, kd).
    set pid:setpoint to spd.
    local throt to 0.
    lock throttle to throt.

    lock steering to -ship:velocity:surface.
    until ship:status = "LANDED" {
        local vDown to vDot(body:position:normalized, ship:velocity:surface).
        set throt to pid:update(time:seconds, vDown).
        set throt to clamp(throt, 0, 1).
        if throt <= 0.01 {
            pid:reset().
        }
    }
    lock steering to up.
    lock throttle to 0.
    wait 5.
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
