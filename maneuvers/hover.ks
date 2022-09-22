@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

global kHover to lexicon().
set kHover:Stop to "STOP".
set kHover:Hover to "HOVER".
set kHover:Descend to "DESCEND".

local kSpdV to 0.3.
local kJerkH to 0.2.
local kMaxAccel to 1.
local kMaxSpd to 50.
local kMaxSpdV to 30.
local kLockDist to 50.
local kAhead to 2.
local kAheadDistance to 30.

global hoverParams to lexicon(
    // adjust these
    // "tgt", target,
    "tgt", vessel("helipad"),
    // "tgt", waypoint("ksc"),
    // "tgt", waypoint("island airfield"),
    "mode", kHover:Stop,
    "seek", false,
    "minAGL", 10,
    "minAMSL", 50,
    "favAAT", 12,
    "altOffset", 0,
    "minG", 0.8,

    // shared values
    "travel", facing,
    "face", facing,

    // cached values
    "throttlePid", hoverPid(),
    "prevTime", time:seconds,
    "prevA", v(0, 0, 0), // in world frame, z unused 
    "bounds", ship:bounds
).

// params:travel = x is around, y is away from target, z is up.
// params:face = x is right, y is up, z is facing direction.
// Far away from the target, these will line up. Close to the target,
// the face direction will be locked in place, but travel will keep updating. 

// stage.
// sas off.
// lock steering to hoverSteering(hoverParams).
// lock throttle to hoverThrottle(hoverParams).

// set hoverParams:mode to kHover.
// print "Ascent".
// wait until hoverParams:bounds:bottomaltradar > 5. 
// print "Fly".
// set hoverParams:seek to true.
// // wait 120.
// wait until abs((hoverParams:travel:inverse * hoverParams:tgt:position):y) < 0.1.
// print "Reduce Hspd".
// wait 5.
// print "Descent".
// set hoverParams:mode to kHover:Descend.
// wait until hoverParams:bounds:bottomaltradar < 0.2.
// set hoverParams:mode to kHover:Stop.
// set hoverParams:seek to false.
// set hoverParams:tgt to waypoint("ksc").
// wait 1.
// set hoverParams:seek to true.
// wait until abs((hoverParams:travel:inverse * hoverParams:tgt:position):y) < 0.1.
// set hoverParams:mode to kHover:Descend.
// wait until hoverParams:bounds:bottomaltradar < 0.3.
// set hoverParams:mode to kHover:Stop.



function hoverSteering {
    parameter params.

    return params:face.
}

function hoverThrottle {
    parameter params.
    
    if params:mode = kHover:Stop {
        return 0.
    }

    set params:face to hoverForward(params).

    local travel to lookDirUp(-body:position, -params:tgt:position).
    set params:travel to travel.

    local hacc to hoverHAccel(params).

    local pid to params:throttlePid.
    local h to hoverAlt(params).
    local tgtVspd to sgn(h) * hoverSpdCurve(abs(h) * kSpdV).
    set tgtVspd to clamp(tgtVspd, -kMaxSpdV, kMaxSpdV).
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
    local worldThrust to hacc + out * gv.
    set params:face to lookDirUp(worldThrust, params:face:upvector).

    // local totalAcc to sqrt(gv ^ 2 + hacc:mag ^ 2).
    local totalAcc to worldThrust:mag.
    local throt to 0.
    if ship:maxthrust <> 0 {
        set throt to totalAcc / (ship:maxthrust / ship:mass). 
    }

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
 
    // altitude
    local seaAlt to params:minAMSL.
    // clear obstacles
    local clearAlt to maxGround + radarOffset + params:minAGL.
    local avgAlt to avgGround + radarOffset + params:favAAT.
    local safeAlt to max(seaAlt, max(clearAlt, avgAlt)).
    // clearScreen.
    // print grounds.
    // print seaAlt + ", " + round(clearAlt, 2) + ", " + round(avgAlt, 2).
    if params:mode = kHover:Hover {
        set safeAlt to safeAlt + params:altOffset.
    }

    return safeAlt - (altitude - radarOffset).
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
    local travelInv to travel:inverse.
    local curAWorld to params:prevA.
    local curA to travelInv * curAWorld.
    local toTgt to travelInv * params:tgt:position.
    local travelV to travelInv * velocity:surface.
    set curA:z to 0.
    set toTgt:z to 0.
    set travelV:z to 0.

    local promisedDV to curA * curA:mag / kJerkH / 2.
    local promisedV to travelV + promisedDV.

    local desiredV to v(0, 0, 0).
    if params:seek = true {
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
    local worldA to travel * newA.
    set params:prevA to worldA.

    // print "promisedV " + vecRound(promisedV, 2) + " desiredV " + vecRound(desiredV, 2)
        // + " desiredA " + vecRound(desiredA, 2) + " newA " + vecRound(newA, 2).

    return worldA.
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