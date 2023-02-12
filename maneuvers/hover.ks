@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

// This controller hovers a vessel toward a target. It's based on the assumption
// that if we limit the "jerk" or change in acceleration to a small amount, we
// can assume the rotation to match that change is instantaneous.
// In atmosphere, the conservative rotation and acceleration limits help to keep
// a craft stable and controllable even with juno engines with slow response and
// no gimbal.
// In vaccum, this controller is not as quick or efficient as it could be, but
// it's still very precise. Travelling long distances over terrain on the mun
// with this looks really cool, but consumes a lot of propellant.

global kHover to lexicon().
set kHover:Stop to "STOP".
set kHover:Hover to "HOVER".
set kHover:Descend to "DESCEND".
set kHover:Vspd to "VSPD".

local kLockDist to 50.
local kAhead to 2.
local kAheadDistance to 30.

function hoverDefaultParams {
    return lexicon(
        // adjust these
        // "tgt", target,
        // "tgt", vessel("helipad"),
        "tgt", waypoint("ksc"),
        // "tgt", waypoint("island airfield"),
        "mode", kHover:Stop,
        "seek", false,
        "crab", false,
        "vspdCtrl", 0,

        // shared values
        "travel", facing,
        "face", facing,
        "throttle", 0,

        // cached values
        "throttlePid", hoverPid(),
        "prevTime", time:seconds,
        "prevA", v(0, 0, 0), // in world frame, z unused 
        "bounds", ship:bounds,

        // constants
        "minAGL", 10,
        "favAAT", 12,
        "cruiseCrab", true,
        "minG", 0.8,
        "spdPerH", 0.3,
        "jerkH", 0.4,
        "maxAccelH", 0.2,
        "maxSpdH", 50,
        "maxSpdV", 30
    ).
}

// params:travel = x is around, y is away from target, z is up.
// params:face = x is right, y is up, z is facing direction.
// Far away from the target, these will line up. Close to the target,
// the face direction will be locked in place, but travel will keep updating. 

function hoverSteering {
    parameter params.

    return params:face.
}

function hoverThrottle {
    parameter params.

    return params:throttle.
}

function hoverLock {
    parameter params.

    lock steering to hoverSteering(params).
    lock throttle to hoverThrottle(params).
}

function hoverUnlock {
    unlock steering.
    unlock throttle.
}

function hoverIter {
    parameter params.
    
    if params:mode = kHover:Stop {
        set params:throttle to 0.
        return 0.
    }

    local travel to lookDirUp(-body:position, -params:tgt:position).
    set params:travel to travel.

    local hacc to hoverHAccel(params).

    local pid to params:throttlePid.
    local tgtVspd to params:vspdCtrl.
    if params:mode <> kHover:Vspd {
        set tgtVspd to hoverVspd(params).
    }
    local out to -body:position:normalized.
    local curVspd to vDot(ship:velocity:surface, out).
    // print tgtVspd + ", " + curVspd.
    set pid:setpoint to tgtVspd.
    local vacc to pid:update(time:seconds, curVspd).

    local g to gat(altitude).
    local gv to g + vacc.
    local minA to g * params:minG.
    if gv < minA {
        set gv to minA.
        pid:reset().
    }
    local worldThrust to hacc + travel:forevector * gv.
    local hoverUpV to hoverUp(params).
    set params:face to lookDirUp(worldThrust, hoverUpV).

    local totalAcc to worldThrust:mag.
    local throt to 0.
    if ship:maxthrust <> 0 {
        set throt to totalAcc / (ship:maxthrust / ship:mass). 
    }
    if status <> "FLYING" {
        set throt to throt * 1.5.
    }

    set throt to clamp(throt, 0, 1).
    set params:throttle to throt.

    // print "Radar: " + round(params:bounds:bottomaltradar)
    //       + " gv: " + round(gv, 1) 
    //       + " hacc: " + round(hacc, 1)
    // print "real: " + round(vang(facing:vector, up:vector), 1)
        //   + " theta: " + round(theta, 1).
}

function hoverSpdCurve {
    parameter s.
    return min(s, sqrt(s)).
}

function hoverAlt {
    parameter params.
    // expected to be positive
    local radar to params:bounds:bottomaltradar.
    local radarOffset to (altitude - params:bounds:bottomalt).
    local position to ship:position.

    if params:mode = kHover:Descend {
        return 0.1 - radar.
    }

    local positions to list(position, params:tgt:position).
    for i in range(1, kAhead + 1) {
        local deltaGrid to v(0, -i * kAheadDistance, 0).
        local deltaWorld to params:travel * deltaGrid.
        positions:add(position + deltaWorld).
    }
    local maxGround to -10000.
    local avgGround to 0.
    local grounds to list().
    for p in positions {
        local g to terrainHAt(p).
        grounds:add(g).
        set maxGround to max(maxGround, g).
        set avgGround to avgGround + g / positions:length.
    }
 
    // clear obstacles
    local clearAlt to maxGround + radarOffset + params:minAGL.
    local avgAlt to avgGround + radarOffset + params:favAAT.
    // print "clear " + round(clearAlt) + " avgAlt " + round(avgAlt)
    //     + " radar " + round(radarOffset) 
    //     + " " + vecround(params:travel:inverse * params:tgt:position).
    local safeAlt to max(clearAlt, avgAlt).
    if params:mode = kHover:Hover {
        set safeAlt to safeAlt.
    }

    return safeAlt - altitude.
}

function hoverVspd {
    parameter params.

    local h to hoverAlt(params).
    local tgtVspd to sgn(h) * hoverSpdCurve(abs(h)) * params:spdPerH.
    set tgtVspd to clamp(tgtVspd, -params:maxSpdV, params:maxSpdV).

    return tgtVspd.
}

function hoverUp {
    parameter params.

    local out to -body:position.
    local towards to removeComp(params:tgt:position, out).
    local tooClose to towards:mag < kLockDist.
    local tooUnstable to vxcl(facing:forevector, ship:angularvel):mag > 0.5.
    if  tooClose or tooUnstable {
        return params:face:upvector.
    }
    if params:crab {
        set towards to vcrs(towards, out).
    }
    return -1 * towards.
}

function hoverHAccel {
    parameter params.

    if abs(verticalSpeed) > params:maxSpdV {
        return zeroV.
    }

    local travel to params:travel.
    local travelInv to travel:inverse.
    local curAWorld to params:prevA.
    local curA to travelInv * curAWorld.
    local toTgt to travelInv * params:tgt:position.
    local travelV to travelInv * velocity:surface.
    local jerk to params:jerkH.
    set curA:z to 0.
    set toTgt:z to 0.
    set travelV:z to 0.

    // The promise refers to the velocity that our acceleration will grant us
    // before we can bring the acceleration vector back to 0. Because of the
    // constant jerk assumption, it can be calculated exactly.

    // Velocity promised from current acceleration
    local promisedDV to curA * curA:mag / jerk / 2.
    // Final velocity when back to 0.
    local promisedV to travelV + promisedDV.
    // The desiredV is the amount we expect to be able to zero out by the time
    // we reach the target.
    local desiredV to v(0, 0, 0).
    if params:seek {
        local spd2 to toTgt:y * jerk - curA:y.
        local spd to sgnSqrt(spd2 / 2).
        set desiredV:y to clamp(spd, -params:maxSpdH, params:maxSpdH).
    }

    local desiredA to desiredV - promisedV.
    local errorA to desiredA - curA.
    local timeDiff to max(time:seconds - params:prevTime, 0.001).
    // Accel can only be changed by an amount within the jerk limit.
    local deltaA to vecClampMag(errorA, jerk * timeDiff).
    local newA to curA + deltaA.

    set newA to vecClampMag(newA, params:maxAccelH * gat(altitude)).
    set params:prevTime to time:seconds.
    local worldA to travel * newA.
    set params:prevA to worldA.

    // print "promisedV " + vecRound(promisedV, 2)
    //     + " desiredV " + vecRound(desiredV, 2)
    //     + " desiredA " + vecRound(desiredA, 2)
    //     + " towards " + vecround(toTgt, 2).

    return worldA.
}

function hoverPid {
    local kp to 0.5.
    local ki to 0.05.
    local kd to 0.5.
    return pidloop(kp, ki, kd).
}

function hoverHoverToFlight {
    lock throttle to 1.
    lock steering to heading(shipHeading(), 85, 0).
    wait 5.
    lock steering to heading(shipHeading(), 45, 0).
    wait 10.
}

function hoverFlightToHover {
    print "Transition to 45".
    lock steering to heading(shipHeading(), 45, 0).
    lock throttle to 1.
    wait 3.
    print "Transition to 85".
    lock steering to heading(shipHeading(), 85, 0).
    lock throttle to ship:mass * gat(altitude) / ship:maxthrust.
    wait 3.
}