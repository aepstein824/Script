@LAZYGLOBAL OFF.

runOncePath("0:common/filters.ks").
runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:common/report.ks").
runOncePath("0:deps/kLA-ks/src/kla").

global kFlight to lexicon().
set kFlight:ThrotKp to 0.1. // 1=full throttle at 1m/s
set kFlight:ThrotMaxA to 0.1. 
set kFlight:AoAKp to 2. // 1 m/s vertical = X degree
set kFlight:AoAMaxA to 1.
set kFlight:AeroCount to 20.

set kFlight:Park to "PARK".
set kFlight:Takeoff to "TAKEOFF".
set kFlight:Level to "LEVEL".
set kFlight:Landing to "LANDING".
set kFlight:Smooth to "SMOOTH".
set kFlight:Rough to "ROUGH".

function flightDefaultParams { 
    local params to lexicon(
        // maintain
        "mode", kFlight:Park,
        "vspd", 0,
        "hspd", 0,
        "xacc", 0.0,
        "landStyle", kFlight:Smooth,

        // calculations
        "level", ship:facing,
        "throttlePid", flightThrottlePid(),
        "aoaPid", flightAoAPid(),
        "aero", flightAeroState(),

        // output
        "steering", ship:facing,
        "throttle", 0,

        // vis
        "arrowVec", v(0, 0, 0),
        "report", false,

        // constants
        "takeoffAoA", 8,
        "takeoffHeading", 90,
        "landV", 28,
        "maneuverV", 35,
        "cruiseV", 43,
        "descentV", -2,
        "smoothV", -1,
        "brakeWait", 3
    ).
    // local arrow to flightArrow(params).
    // set params:arrow to arrow.
    local differ to flightDifferCreate(params).
    set params:differ to differ.
    return params.
}

function flightSteering {
    parameter params.

    if params:mode = "LEVEL" or params:mode = "LANDING" {
        flightDifferUpdate(params).

        // We have to recalc every time since we're spinning
        local level to shipLevel().
        // HACK ALERT
        // Cooked steering chooses pyr outputs by converting angle error into
        // rotation velocity. As we're turning, it sees the resulting angular
        // momentum as part of that velocity. However, it doesn't take into
        // account that it needs to add rotation on top of the turn in order to
        // move the facing vector relatve to prograde. In fact, it often sees
        // us as rolling too fast already, and triggers yaw in the opposite
        // direction. This hack adds additional rotation error to trigger
        // equivalent rotational velocity. Because kp = 1, I believe this is an
        // exact solution.
        local spd to groundspeed.
        local turnOmega to flightSpdToOmega(spd, params:xacc).
        local hack to r(0, turnOmega, 0).
        local steer to level * hack * params:steering.
        // local steer to level * params:steering.
        // set params:arrowvec to steer:forevector.

        return steer.
    }
    return params:steering.

}

function flightThrottle {
    parameter params.

    return params:throttle.
}

function flightArrow {
    parameter params.

    return vecdraw(
        { return ship:position. },
        { return ship:position + 10 * params:arrowVec. },
        green, "V", 1.0, false, 0.2, true).
}

function flightIter {
    parameter params.

    local out to -body:position.
    local lev to removeComp(velocity:surface, out).
    // local lev to vxcl(out, velocity:surface).
    set params:level to lookDirUp(lev, out).

    if not params:report:istype("BOOLEAN") {
        for k in params:report:keyToVal:keys {
            set params:report["keyToVal"][k]:text 
                to round(params[k], 2):tostring().
        }
    }

    if params:mode = kFlight:Takeoff {
        flightTakeoff(params).
    } else if params:mode = kFlight:Level {
        flightLevel(params).
    } else if params:mode = kFlight:Landing {
        flightLanding(params).
    }
}

function flightSetSpeedsGivenMin {
    parameter params, minSpd.

    set params:landV to max(params:landV, minSpd + 2).
    set params:cruiseV to max(params:cruiseV, minSpd * 1.4).
    set params:maneuverV to max(params:maneuverV, minSpd * 1.2).
}

function flightTakeoff {
    parameter params.

    set params:steering to heading(params:takeoffHeading, params:takeoffAoA).
    set params:throttle to 1.

    if status = "LANDED" {
        flightSetSpeedsGivenMin(params, groundspeed).
    }
}

function flightDifferCreate {
    parameter params.
    local newValues to flightDifferValues(params).
    return differCreate(newValues, time:seconds).
}

function flightDifferValues {
    parameter params.
    local srfRolled to lookDirUp(srfPrograde:forevector, facing:upvector).
    return list(
        velocity:surface
    ).
}

function flightDifferUpdate {
    parameter params.
    local newValues to flightDifferValues(params).
    return differUpdate(params:differ, newValues, time:seconds).
}

function flightAeroState {
    return lexicon(
        "In", klaOnes(kFlight:AeroCount, 2), 
        "Out", klaZeros(kFlight:AeroCount, 2),
        "LastTick", 0,
        "Iter", 0,
        "Aoa", 0,
        "Thrust", 0,
        "LandingSpd", 0
    ).
}

function flightLevelAoaLinear {
    parameter aero, vspd, hspd, grav, acc.

    local x to aero:In.
    local y to aero:Out.
    local i to aero:Iter.
    local lastTick to aero:LastTick.
    local nowTick to time:seconds.
    set aero:LastTick to nowTick.
    set aero:Iter to mod(i + 1, kFlight:AeroCount).
 
    local air2 to airspeed ^ 2.

    local srfRolled to lookDirUp(srfPrograde:forevector, facing:upvector).

    local totalThrust to 0.
    local engs to list().
    list engines in engs.
    for e in engs {
        set totalThrust to totalThrust + e:thrust. 
    }
    local thrustAccRaw to ship:facing:forevector * totalThrust / ship:mass.
    local gravAccRaw to gat(altitude) * body:position:normalized.
    local aeroAcc to srfRolled:inverse * (acc - thrustAccRaw - gravAccRaw).
    local aeroforceDiff to aeroAcc * ship:mass.
    local aeroforce to aeroforceDiff.

    // local aoa to smallAng(vectorAngleAround(
    //     srfRolled:forevector, 
    //     facing:rightvector,
    //     facing:forevector)).
    local aoa to 90 - vang(srfRolled:upvector, facing:forevector).
    local lift to aeroforce:y.
    local drag to aeroforce:z.
    local cl to lift / air2.
    local cd to drag / air2.

    klaSet(x, i + 1, 2, aoa).
    klaSet(y, i + 1, 1, cl).
    klaSet(y, i + 1, 2, cd).    

    if i = kFlight:AeroCount - 1 {
        local solution to klaBackslash(x, y).
        clearScreen.
        local b to klaGet(solution, 1, 1).
        local m to klaGet(solution, 2, 1).
        local bd to klaGet(solution, 1, 2).
        local md to klaGet(solution, 2, 2).
        local aoaPred to (cl - b) / m.
        local aoaPredD to (cd - bd) / md.
        local zeroAoA to -b / m.
        local liftPred to (m * aoa + b) * air2.
        local dragPred to (md * aoa + bd) * air2.

        local spd2 to vspd ^ 2 + hspd ^ 2.
        local vmag to sqrt(spd2).
        local sinP to vspd / vmag.
        local cosP to hspd / vmag.
        local Gmag to grav * ship:mass.
        local prevThrust to aero:Thrust.
        local GdotL to -Gmag * cosP.
        local GdotD to Gmag * sinP.

        // small angle approximation of thrust * sin(aoa).
        local stable to ((-GdotL) / (spd2) - b) 
            / (m + constant:degtorad * prevThrust / spd2).
        set stable to aoa + clamp(stable - aoa, -2, 2).
        // set stable to (stable + aoa) / 2.
        local stableDrag to -1 * (md * stable + bd) * spd2.
        local stableThrust to (1 / cos(stable)) * (stableDrag + GdotD).

        local sevCl to m * (zeroAoA + 10) + b.
        local sevSpd to sgnsqrt(Gmag / sevCl) + 5.

        // klaPrint(x).
        // print " -- ".
        // klaPrint(y).
        // print " -- ".
        // klaPrint(solution).
        // print " -- ".
        // print i.
        // print "Diff " + vecround(aeroforceDiff, 2).
        print "tickms " + ((nowTick - lastTick) * 1000).
        print "energy " + (0.5 * airspeed ^ 2 + 9.8 * altitude).
        print "aoa " + aoa.
        print "lift / G " + round(lift / Gmag, 2).
        print "drag / G " + round(drag / Gmag, 2).
        print "cl " + cl.
        print "cd " + cd.
        print "pitch angle " + round(arcsin(sinP), 2).
        print "stable aoa at " + round(hspd) + " = " + stable.
        print "stable thrust " + stableThrust.
        print "aoapred " + aoaPred.
        print "error " + round((aoaPred - aoa) / aoa, 4).
        print "aoapredD " + aoaPredD.
        print "error " + round((aoaPredD - aoa) / aoa, 4).
        print "lift pred " + liftPred.
        print "error " + round((liftPred - lift) / lift, 4).
        print "drag pred " + dragPred.
        print "error " + round((dragPred - drag) / drag, 4).
        print "stall speed " + sevSpd.
        print "zero aoa " + round(zeroAoA, 2).

        set aero:Aoa to stable.
        set aero:Thrust to stableThrust.
        set aero:LandingSpd to sevSpd.
    }

    return v(aero:Aoa, aero:Thrust, 0).

}


function flightLevel {
    parameter params.

    local level to params:level.

    local levelSurf to level:inverse * velocity:surface.
    local vspd to params:vspd.
    local hspd to params:hspd.

    // roll
    local grav to gat(altitude).
    local rollUp to v(params:xacc, grav, 0).
    local rollGrav to rollUp:mag.

    local acc to params:differ:D[0].
    local aoaThrust to flightLevelAoaLinear(params:aero, vspd, hspd, rollGrav, acc).
    local aoa to aoaThrust:x.
    local thrust to aoaThrust:y.
    if params:aero:LandingSpd > 10 {
        set params:landV to params:aero:LandingSpd.
    }

    // PIDs
    local aoaPid to params:aoaPid.
    // set aoaPid:setpoint to params:vspd - hspd / 5.
    set aoaPid:setpoint to vspd.
    // local aoaOffset to aoaPid:update(time:seconds, 
    //     levelSurf:y - levelSurf:z / 5).
    local aoaOffset to aoaPid:update(time:seconds, levelSurf:y).
    // calculate a throttle adjustment, but remember to count falling as -spd
    local throttlePid to params:throttlePid.
    // set throttlePid:setpoint to hspd + 5 * vspd.
    set throttlePid:setpoint to hspd.
    // local signedSurf to levelSurf:z + 5 * levelSurf:y.
    // local throtAdj to throttlePid:update(time:seconds, signedSurf).
    local throtAdj to throttlePid:update(time:seconds, levelSurf:z).
    // set aoaOffset to 0.
    // set throtAdj to 0.
    print "a " + round(aoaOffset, 2) + " t " + round(throtAdj, 2) 
        + " A " + round(aoaOffset + aoa, 2).

    // pitch
    local pitchA to arcTan2(vspd, hspd).
    local travel to flightPitch(pitchA).
    local aoaRots to flightPitch(aoa + aoaOffset).
    local rolled to lookDirUp(unitZ, rollUp).
    local flight to travel * rolled * aoaRots.
    set params:steering to flight.

    // throttle
    local idealThrot to thrust / max(ship:maxThrust, 0.01).
    // Keep throttle above 0 to keep it ready for throttling up.
    // set throtAdj to 0.
    set params:throttle to max(idealThrot + throtAdj, 0.02).
}

function flightLanding {
    parameter params.

    local rough to params:landStyle = kFlight:Rough.
    local flareSteer to heading(shipHeading(), 5).
    if status = "LANDED" {
        set params:throttle to 0.
        if groundspeed < (params:hspd - params:brakeWait) or rough {
            brakes on.
        }

        if groundspeed > 5 {
            local reverser to setThrustReverser(kReverse).
            if reverser {
                set params:throttle to 100.
            }
        } else {
            setThrustReverser(kForward).
        }

        set params:steering to params:level:inverse * flareSteer.
        return.
    }

    if groundAlt() < 10 {
        set params:steering to params:level:inverse * flareSteer.
        set params:throttle to 0.1.
        return.
    }
    flightLevel(params).
}

function flightPitch {
    parameter pitch.

    // args are right hand, R() is left hand
    return r(-pitch, 0, 0).
}

function flightBeginTakeoff {
    parameter params.

    if params:mode <> kFlight:Takeoff {
        set params:mode to kFlight:Takeoff.

        setFlaps(2).
        setThrustReverser(kForward).
        brakes off.
    }
}

function flightBeginLevel {
    parameter params.

    if status <> "FLYING" {
        return.
    }
    if params:mode <> kFlight:Level {
        set params:mode to kFlight:Level.
        set params:steering to r(0, 0, 0).

        flightResetSpds(params, params:cruiseV).
        setFlaps(0).
        setThrustReverser(kForward).
        brakes off.
        gear off.
    }
}

function flightBeginLanding {
    parameter params.

    if status <> "FLYING" and status <> "LANDED" {
        return.
    }
    if params:mode <> kFlight:Landing {
        set params:mode to kFlight:Landing.
        set params:steering to r(0, 0, 0).

        flightResetSpds(params, params:landV).
        setThrustReverser(kForward).
        set params:vspd to -1.
        setFlaps(3).
        brakes off.
        gear on.
    }
}

function flightResetSpds {
    parameter params, hspd.

    set params:hspd to hspd.
    set params:vspd to 0.
    set params:xacc to 0.
}

function flightCreateReport {
    parameter params.   

    set params:report to reportCreate(list(
        "vspd", "hspd", "xacc", 
        "landV", "maneuverV", "cruiseV")).


    wait 0.
    set params:report:gui:x to 300.
    set params:report:gui:y to -300.
    params:report:gui:show().
}

function flightThrottlePid {
    local pid to pidloop(kFlight:ThrotKp, 0, kFlight:ThrotKp / 10).
    set pid:maxoutput to kFlight:ThrotMaxA.
    set pid:minoutput to -kFlight:ThrotMaxA.
    return pid.
}

function flightAoAPid {
    local pid to pidloop(kFlight:AoAKp, 0, kFlight:AoAKp / 10).
    set pid:maxoutput to kFlight:AoAMaxA.
    set pid:minoutput to -kFlight:AoAMaxA.
    return pid.
}

function flightSpdToOmega {
    parameter spd, a.
    return a / spd * constant:radtodeg.
}

function flightSpdToRadius {
    parameter spd, a.
    return spd ^ 2 / a.
}

function flightSpdToXacc {
    parameter spd, radius.
    return spd ^ 2 / radius.
}

function flightSetSteeringManager {
    steeringManager:resettodefault().
    set steeringmanager:showsteeringstats to false.
    // Setting the roll range to 180 forces roll control everywhere
    set steeringmanager:rollcontrolanglerange to 180.
    // The stop time calc doesn't work for planes
    set steeringmanager:maxstoppingtime to 100.
    // kp defaults to be 1, but we need to be sure for a hack in our steering
    set steeringmanager:yawpid:kp to 1.
    set steeringmanager:pitchpid:kp to 1.
    // we don't want to accumulate anything in level flight
    set steeringmanager:pitchpid:ki to 0.
    set steeringmanager:rollpid:ki to 0.
    set steeringmanager:yawpid:ki to 0.
}