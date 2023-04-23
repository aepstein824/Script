@LAZYGLOBAL OFF.

runOncePath("0:common/control.ks").
runOncePath("0:common/geo.ks").
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
local kAirFactor to 3.
local kVacc to 0.2.
local kVaccTime to 10.
local kMaxVspd to 30.
local kHacc to 0.2.
local kHaccTime to 20.
local kMaxHspd to 50.


function hoverDefaultParams {
    local params to lexicon(
        // adjust these
        // "tgt", target,
        // "tgt", vessel("helipad"),
        "tgt", waypoint("ksc"),
        // "tgt", waypoint("island airfield"),
        "mode", kHover:Stop,
        "seek", false,
        "crab", true,
        "vspdCtrl", 0,

        // shared values
        "travel", facing,
        "face", facing,
        "thrust", thrustCreate(),
        "throttle", 0,
        "vspdCurve", smoothAccelFunc(kVacc * gat(0), kVaccTime, kMaxVspd),
        "hspdCurve", smoothAccelFunc(kHacc * gat(0), kHaccTime, kMaxHspd),

        // cached values
        "throttlePid", hoverPid(),
        "prevTime", time:seconds,
        "prevA", v(0, 0, 0), // in world frame, z unused 
        "bounds", ship:bounds,

        // constants
        "airbreathing", true,
        "minAGL", 30,
        "favAAT", 32,
        "minG", 0.8,
        "maxAccelH", 0.6 * kHacc
    ).
    return params.
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
    set params:bounds to ship:bounds.
}

function hoverUnlock {
    unlock steering.
    unlock throttle.
}

function hoverSwitchMode {
    parameter params, mode.

    set params:mode to mode.
    set params:airbreathing to shipActiveEnginesAirbreathe().
    local timeFactor to choose kAirFactor if params:airbreathing else 1.
    set params:vspdCurve to smoothAccelFunc(
        kVacc * (1 - params:minG) * gat(0), 
        timeFactor * kVaccTime, kMaxVspd).
    set params:hspdCurve to smoothAccelFunc(
        .45 * params:maxAccelH * gat(0),
        timeFactor * kHaccTime, kMaxHspd).
}

function hoverIter {
    parameter params.
    
    local mode to params:mode.
    if mode = kHover:Stop {
        set params:throttle to 0.
        return 0.
    }

    local travel to lookDirUp(-body:position, -params:tgt:position).
    set params:travel to travel.
    local onGround to shipIsLandOrSplash().

    local hacc to zeroV.
    if not onGround {
        set hacc to hoverHAccField(params).
    }

    local g to gat(altitude).
    local pid to params:throttlePid.
    local tgtVspd to params:vspdCtrl.
    local tgtVacc to 0.
    if mode <> kHover:Vspd {
        local tgtAlti to hoverAlt(params).
        local vspdAndAcc to funcAndDeriv(params:vspdCurve, tgtAlti).
        set tgtVspd to vspdAndAcc[0].
        set tgtVacc to vspdAndAcc[1] * tgtVspd.
        if mode = kHover:Descend {
            set tgtVspd to min(tgtVspd, -0.1).
        }
    }

    local stableThrust to g * mass.
    local curVspd to verticalSpeed + hoverPromisedVspd(params, stableThrust).
    set pid:setpoint to tgtVspd.
    local vacc to tgtVacc + pid:update(time:seconds, curVspd).

    local gv to g + vacc.
    local minA to g * params:minG.
    if gv < minA {
        set gv to minA.
    }
    local worldAcc to hacc + travel:forevector * gv.
    local hoverUpV to hoverUp(params).
    set params:face to lookDirUp(worldAcc, hoverUpV).

    // print "tgtVspd " + round(tgtVspd, 2)
    //     + "  |   tgtVacc " + round(tgtVacc, 2)
    //     + "  |   gv " + round(gv, 2)
    //     + "  |   worldAcc " + vecround(worldAcc, 2).

    local totalAcc to worldAcc:mag.
    local throt to hoverThrotUpdate(params, totalAcc).
    if onGround {
        if mode = kHover:Hover or (mode = kHover:Vspd and params:vspdCtrl > 0) {
            set throt to 1.
        } else {
            set throt to 0.
        }
        set params:face to lookDirUp(travel:forevector, facing:upvector).
    }

    set throt to clamp(throt, 0, 1).
    set params:throttle to throt.
}

function hoverPromisedVspd {
    parameter params, stableThrust.

    local maxiThrust to ship:maxthrust.
    if maxiThrust <= 0 or not params:airbreathing {
        return 0.
    }
    
    local thrustState to params:thrust.
    local nowThrot to ship:thrust / maxiThrust.
    local stableThrot to stableThrust / maxiThrust.
    local throtPromise to thrustPromiseForGoal(thrustState, nowThrot,
        stableThrot).
    local spdPromise to throtPromise * maxiThrust / mass.
    return spdPromise.
}

function hoverThrotUpdate {
    parameter params, totalAcc.

    local maxiThrust to ship:maxthrust.
    if maxiThrust <= 0 {
        return 0.
    }
    local nowThrot to ship:thrust / maxiThrust.
    local tgtThrust to totalAcc * mass.
    local tgtThrot to tgtThrust / maxiThrust.
    if not params:airbreathing {
        return tgtThrot.
    }
    local thrustState to params:thrust.
    thrustUpdate(thrustState, time:seconds, nowThrot, tgtThrot).
    return thrustState:throt.
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

    local positions to list(position).
    if params:seek {
        positions:add(params:tgt:position).
    }
    local aheadOffset to groundspeed * 2.
    for i in range(1, kAhead + 1) {
        local deltaGrid to v(0, -i * (kAheadDistance + aheadOffset), 0).
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

function hoverHAccField {
    parameter params.

    local travel to params:travel.
    local travelInv to travel:inverse.
    local travelV to travelInv * velocity:surface.
    local toTgt to travelInv * params:tgt:position.
    set toTgt:z to 0.
    set travelV:z to 0.

    local tgtVel to zeroV.
    local tgtAcc to zeroV.
    if params:seek {
        local fieldSpdAndAcc to funcAndDeriv(params:hspdCurve, toTgt:mag).
        local tgtNormalized to toTgt:normalized.
        set tgtVel to tgtNormalized * fieldSpdAndAcc[0].
        set tgtAcc to tgtNormalized * fieldSpdAndAcc[1] * fieldSpdAndAcc[0].

        if toTgt:mag < 1 {
            // Countering oscillations close to the target. Would be better
            // served by with a vector based pid controller.
            set tgtVel to tgtVel / 3.
            set tgtAcc to tgtAcc / 3.
        }
    }

    local kp to 0.5.
    local correctionAcc to kp * (tgtVel - travelV).
    local expectedAcc to tgtAcc.
    local desiredAcc to correctionAcc + expectedAcc.

    print "tgtVel  " + vecround(tgtVel, 2)
        + "  |  tgtAcc  " + vecround(tgtAcc, 2)
        + "  |  desAcc  " + vecround(desiredAcc, 2)
        + "  |  toTgt  " + vecround(toTgt, 2).
        // + "  |  hacc   " + round(.45 * params:maxAccelH * gat(0), 1).

    local newA to desiredAcc.
    set newA to vecClampMag(newA, params:maxAccelH * gat(altitude)).
    local worldA to travel * newA.
    return worldA.
}

function hoverPid {
    local kp to 2.
    local ki to 0.0.
    local kd to 0.5.
    return pidloop(kp, ki, kd).
}

function hoverHoverToFlight {
    lock throttle to 1.
    lock steering to heading(shipVHeading(), 85, 0).
    print " Transition to 85".
    wait 5.
    lock steering to heading(shipVHeading(), 30, 0).
    print " Transition to 30".
    wait until velocity:surface:mag > 100.
}

function hoverFlightToHover {
    print " Transition to 45".
    lock steering to heading(shipVHeading(), 45, 0).
    lock throttle to 1.1 * ship:mass * gat(altitude) / ship:maxthrust.
    wait 3.
    print " Transition to 85".
    lock steering to heading(shipVHeading(), 85, 0).
    wait 3.
}