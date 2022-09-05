@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

local kSpdV to 0.3.
local kJerkH to 0.2.
local kMaxAccel to 1.
local kMaxSpd to 30.
local kLockDist to 50.
local kLand to "LAND".
local kHover to "HOVER".
local kFly to "FLY".

global hoverParams to lexicon(
    // adjust these
    // "tgt", waypoint("vab main building"),
    "tgt", waypoint("ksc"),
    "radar", 0,
    "mode", kLand,
    "rzone", 50,

    // shared values
    "travel", facing,
    "face", facing,

    // cached values
    "throttlePid", hoverPid(),
    "prevTime", time:seconds,
    "prevA", v(0, 0, 0), // in travel frame, z unused 
    "bounds", ship:bounds
).

// params:travel = x is around, y is away from target, z is up.
// params:face = x is right, y is up, z is facing direction.
// Far away from the target, these will line up. Close to the target,
// the face direction will be locked in place, but travel will keep updating. 

stage.
lock steering to hoverSteering(hoverParams).
lock throttle to hoverThrottle(hoverParams).

local hoverHeight to 120.
set hoverParams:radar to hoverHeight.
set hoverParams:mode to kHover.
print "Ascent".
wait until hoverParams:bounds:bottomaltradar > hoverHeight - 5. 
print "Fly".
set hoverParams:mode to kFly.
// wait 120.
wait until abs((hoverParams:travel:inverse * hoverParams:tgt:position):y) < 0.5.
print "Reduce Hspd".
set hoverParams:mode to kHover.
wait 5.
print "Descent".
set hoverParams:radar to 5.
wait until hoverParams:bounds:bottomaltradar < 7. 
set hoverParams:radar to 0.
wait until hoverParams:bounds:bottomaltradar < 1.0.
print "Landing".
set hoverParams:mode to kLand.
wait 3.

function hoverSteering {
    parameter params.

    return params:face.
}

function hoverThrottle {
    parameter params.
    
    if params:mode = kLand {
        return 0.
    }

    set params:face to hoverForward(params).

    local prevAOldSpace to params:prevA.
    local travel to lookDirUp(-body:position, -params:tgt:position).
    // doesn't account for change in world frame, but that should be slow
    local prevAWorldSpace to params:travel * prevAOldSpace.
    set params:prevA to travel:inverse * prevAWorldSpace.
    set params:prevA:z to 0.
    set params:travel to travel.

    local hacc to hoverHAccel(params).

    local pid to params:throttlePid.
    local h to params:radar - params:bounds:bottomaltradar.
    local tgtVspd to sgn(h) * hoverSpdCurve(abs(h) * kSpdV).
    local curVspd to vDot(ship:velocity:surface, -body:position:normalized).
    set pid:setpoint to tgtVspd.
    local vacc to pid:update(time:seconds, curVspd).


    local g to gat(altitude).
    local gv to max(g + vacc, 0.01).
    local out to -body:position:normalized.
    local worldThrust to params:travel * hacc + out * gv.
    set params:face to lookDirUp(worldThrust, params:face:upvector).

    // local totalAcc to sqrt(gv ^ 2 + hacc:mag ^ 2).
    local totalAcc to worldThrust:mag.
    local throt to totalAcc / (ship:maxthrust / ship:mass). 

    set throt to clamp(throt, 0, 1).

    // print "Radar: " + round(params:bounds:bottomaltradar)
    //       + " gv: " + round(gv, 1) 
    //       + " hacc: " + round(hacc, 1)
    // print "real: " + round(vang(facing:vector, up:vector), 1)
        //   + " theta: " + round(theta, 1).
    return throt.
}

function hoverSpdCurve {
    parameter s.
    return min(s, sqrt(s)).
}

function hoverAlt {
    parameter params.
}

function hoverForward {
    parameter params.

    local out to -body:position:normalized.
    local towards to removeComp(params:tgt:position, out).
    if towards:mag > kLockDist {
        return lookDirUp(out, -towards).
    } else {
        return params:face.
    }
}

function hoverHAccel {
    parameter params.

    local travel to params:travel.
    local toTgt to removeComp(travel:inverse * params:tgt:position, v(0, 0, 1)).
    local travelV to removeComp(travel:inverse * velocity:surface, v(0, 0, 1)).

    local curA to params:prevA.
    local promisedDV to curA * curA:mag / kJerkH / 2.
    local promisedV to travelV + promisedDV.

    local desiredV to v(0, 0, 0).
    if params:mode = kFly {
        local spd2 to toTgt:y * kJerkH - curA:y.
        local spd to sgnSqrt(spd2 / 2).
        set desiredV:y to clamp(spd, -kMaxSpd, kMaxSpd).
    }

    local desiredA to desiredV - promisedV.
    local errorA to desiredA - curA.
    local timeDiff to min(time:seconds - params:prevTime, 0.05).
    local deltaA to errorA:normalized * kJerkH * timeDiff.
    local newA to curA + deltaA.
    set newA to vecClampMag(newA, kMaxAccel).
    set params:prevTime to time:seconds.
    set params:prevA to newA.

    print "promisedV " + vecRound(promisedV, 2) + " desiredV " + vecRound(desiredV, 2)
        + " desiredA " + vecRound(desiredA, 2) + " newA " + vecRound(newA, 2).

    return newA.
}

function hoverPid {
    local kp to 0.5.
    local ki to 0.05.
    local kd to 0.5.
    // set kp to 0.
    // print "kp = " + kp.
    // set ki to 0.
    // set kd to 0.
    return pidloop(kp, ki, kd).
}