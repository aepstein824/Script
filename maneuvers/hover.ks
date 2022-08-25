@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

local kSpd to 0.3.
local kMaxSpd to 30.
local kLand to "LAND".
local kHover to "HOVER".
local kFly to "FLY".

global hoverParams to lexicon(
    // adjust these
    "tgt", waypoint("ksc"),
    "radar", 0,
    "mode", kLand,

    // shared values
    "theta", 0,

    // cached values
    "throttlePid", hoverPid(),
    "anglePid", hoverAnglePid(),
    "bounds", ship:bounds
).

lock steering to hoverSteering(hoverParams).
lock throttle to hoverThrottle(hoverParams).

local hoverHeight to 50.
set hoverParams:radar to hoverHeight.
set hoverParams:mode to kHover.
print "Ascent".
wait until hoverParams:bounds:bottomaltradar > hoverHeight. 
print "Fly".
set hoverParams:mode to kFly.
wait 20.
print "Reduce Hspd".
set hoverParams:mode to kHover.
wait 10.
print "Descent".
set hoverParams:radar to 1.
wait until hoverParams:bounds:bottomaltradar < 2. 
print "Landing".
set hoverParams:mode to kLand.
wait 3.

function hoverSteering {
    parameter params.

    local out to -body:position:normalized.
    local towards to removeComp(params:tgt:position:normalized, out).
    local tilted to out * cos(params:theta) + towards * sin(params:theta).

    return lookDirUp(tilted, -towards).
}

function hoverThrottle {
    parameter params.
    
    // todo
    // throttle using real angle?
    // low pass radar
    // refactor

    if params:mode = kLand {
        set params:theta to 0.
        return 0.
    }

    local tgtHspd to 0.
    local dist to removeComp(params:tgt:position, body:position).
    local curHspd to vdot(ship:velocity:surface, dist:normalized).
    if params:mode = kFly {
        set tgtHspd to sqrt(dist:mag * kSpd).
        // print "curH: " + round(curHspd, 1) + " tgtH: " + round(tgtHspd, 1).
        set tgtHspd to min(tgtHspd, kMaxSpd).
    }
    local anglePid to params:anglePid.
    set anglePid:setpoint to tgtHspd.
    local hacc to anglePid:update(time:seconds, curHspd).


    local pid to params:throttlePid.
    local h to params:radar - params:bounds:bottomaltradar.
    local tgtVspd to sgn(h) * sqrt(abs(h) * kSpd).
    local curVspd to vDot(ship:velocity:surface, -body:position:normalized).
    set pid:setpoint to tgtVspd.
    local vacc to pid:update(time:seconds, curVspd).


    local g to gat(altitude).
    local gv to max(g + vacc, 0.01).
    local theta to arctan(hacc / gv).
    set params:theta to theta.
    local totalAcc to sqrt(gv ^ 2 + hacc ^ 2).
    local throt to totalAcc / (ship:maxthrust / ship:mass). 

    set throt to clamp(throt, 0, 1).

    // print "Radar: " + round(params:bounds:bottomaltradar)
    //       + " gv: " + round(gv, 1) 
    //       + " hacc: " + round(hacc, 1)
    print "real: " + round(vang(facing:vector, up:vector), 1)
          + " theta: " + round(theta, 1).
    return throt.
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

function hoverAnglePid {
    local kp to 0.05.
    local ki to 0.
    local kd to 0.
    return pidloop(kp, ki, kd).
}