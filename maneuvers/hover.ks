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
    "face", facing:forevector,
    "forward", -facing:topvector,

    // cached values
    "throttlePid", hoverPid(),
    "prevTime", time:seconds,
    "prevA", 0,
    "bounds", ship:bounds
).

lock steering to hoverSteering(hoverParams).
lock throttle to hoverThrottle(hoverParams).

local hoverHeight to 50.
set hoverParams:radar to hoverHeight.
set hoverParams:mode to kHover.
print "Ascent".
wait until hoverParams:bounds:bottomaltradar > hoverHeight - 5. 
print "Fly".
set hoverParams:mode to kFly.
wait 20.
print "Reduce Hspd".
set hoverParams:mode to kHover.
wait 10.
print "Descent".
set hoverParams:radar to 5.
wait until hoverParams:bounds:bottomaltradar < 5.1. 
set hoverParams:radar to 0.
wait until hoverParams:bounds:bottomaltradar < 1.0.
print "Landing".
set hoverParams:mode to kLand.
wait 3.

function hoverSteering {
    parameter params.

    return lookDirUp(params:face, -params:forward).
}

function hoverThrottle {
    parameter params.
    
    if params:mode = kLand {
        set params:theta to 0.
        return 0.
    }

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
    local face to gv * out + hacc * params:forward.
    set params:face to face.
    local totalAcc to sqrt(gv ^ 2 + hacc ^ 2).
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
        return towards:normalized.
    } else {
        return params:forward.
    }
}

function hoverHAccel {
    parameter params.

    local forward to hoverForward(params).
    set params:forward to forward. 

    local timeDiff to min(time:seconds - params:prevTime, 0.05).
    local absFrameJerk to kJerkH * timeDiff.
    local curA to params:prevA.
    local dist to removeComp(params:tgt:position, body:position).
    local curHspd to vdot(ship:velocity:surface, dist:normalized).
    local positive to sgn(curA * curHspd) > 0. 
    local slowJerk to -1 * absFrameJerk * sgn(curA).
    local absA to abs(curA).
    local promisedDV to (curA ^ 2) / kJerkH / 2.

    local reasoning to "uninit".
    local frameJerk to 0.
    if absA > 2 * sqrt(kJerkH * (abs(curHspd) + 1)) and positive {
        // too much acceleration to slow without bounce
        set frameJerk to slowJerk.
        set reasoning to "moderate".
    } else if curHspd > kMaxSpd or 
        absA > 2 * sqrt(kJerkH * (kMaxSpd - abs(curHspd))) {
        // too much acceleration to stop at max speed
        set frameJerk to slowJerk.
        set reasoning to "speedlim".
    } else if params:mode = kHover {
        if abs(curHspd) <  promisedDV {
            // we already have too much deceleration
            set frameJerk to slowJerk.
            set reasoning to "toodecel".
        } else {
            // move to decelerate
            set frameJerk to absFrameJerk * sgn(-curHspd).
            set reasoning to "stpdecel".
        }
    } else if params:mode = kFly {
        // calculate stopping distance
        local vMax to curHspd + sgn(curA) * promisedDV.
        // this stop time assumes currently accelerating
        local dA to abs(curA) / kJerkH.
        local dD to (2 * vMax ^ 2) / kJerkH.
        local stopDist to dA + dD.
        // print "dA " + round(dA) + " dD " + round(dD, 4)
            // + " vMax " + round(vMax, 4).

        if stopDist >  dist:mag {
            set frameJerk to -absFrameJerk * sgn(curHspd).
            set reasoning to "stopdist".
        } else {
            set frameJerk to absFrameJerk.
            set reasoning to "gotoward".
        }
    }

    local hacc to curA + frameJerk.
    set hacc to clamp(hacc, -kMaxAccel, kMaxAccel).
    set params:prevTime to time:seconds.
    set params:prevA to hacc.
    // print reasoning + " hacc " + round(hacc, 5) 
        // + " frameJerk " + round(sgn(frameJerk)).
    return hacc.
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