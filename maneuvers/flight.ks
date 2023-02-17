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
set kFlight:ThrotMaxA to 0.5. 
set kFlight:AoAKp to 2. // 1 m/s vertical = X degree
set kFlight:AoAMaxA to 1.
set kFlight:AeroCount to 10.
set kFlight:FlareHeight to 3.

set kFlight:Park to "PARK".
set kFlight:Takeoff to "TAKEOFF".
set kFlight:Level to "LEVEL".
set kFlight:Landing to "LANDING".

local kPitchNoiseAmp to 0.2.

function flightDefaultParams { 
    local params to lexicon(
        // maintain
        "mode", kFlight:Park,
        "vspd", 0,
        "hspd", 0,
        "xacc", 0.0,

        // calculations
        "differ", flightDifferCreate(),
        "reality", flightRealityCreate(),
        "level", shipLevel(),
        "throttlePid", flightThrottlePid(),
        "aoaPid", flightAoAPid(),
        "aero", flightAeroCreate(),
        "landV", 65,
        "landVUpdateK", 0,

        // output
        "steering", ship:facing,
        "throttle", 0,

        // vis
        "arrowVec", v(0, 0, 0),
        "report", false,

        // constants
        "takeoffAoA", 8,
        "takeoffHeading", 90,
        "landingUpdateK", 0.1,
        "levelUpdateK", 0.5,
        "maneuverV", 75,
        "cruiseV", 90,
        "descentV", -2,
        "landTime", -1
    ).
    // local arrow to flightArrow(params).
    // set params:arrow to arrow.
    return params.
}

function flightSteering {
    parameter params.

    if params:mode = "LEVEL" or params:mode = "LANDING" {
        flightDifferUpdate(params:differ).

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

    set params:level to shipLevel().

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
    local newValues to flightDifferValues().
    return differCreate(newValues, time:seconds).
}

function flightDifferValues {
    return list(
        velocity:surface
    ).
}

function flightDifferUpdate {
    parameter differ.
    local newValues to flightDifferValues().
    return differUpdate(differ, newValues, time:seconds).
}

function flightRealityCreate {
    // TODO add thrust
    return lexicon(
        "Gs", 0,
        "Vs", 0,
        "Tas", 0,
        "Aoa", 0,
        "Dyn", 1,
        "Surf", zeroV,
        "Acc", zeroV,
        "Time", time:seconds,
        "Alt", 0,
        "Pro", facing
    ).
}

function flightRealityUpdate {
    parameter reality, acc.
    set reality:Gs to groundspeed.
    set reality:Vs to verticalSpeed.
    set reality:Tas to airspeed.
    set reality:Surf to velocity:surface.
    set reality:Aoa to vang(reality:Surf, facing:upvector) - 90.
    set reality:Dyn to ship:dynamicpressure.
    set reality:Acc to acc.
    set reality:Time to time:seconds.
    set reality:Alt to altitude.
    set reality:Pro to lookDirUp(srfPrograde:forevector, facing:upvector).
}

function flightAeroCreate {
    return lexicon(
        "In", klaOnes(kFlight:AeroCount, 2), 
        "Out", klaZeros(kFlight:AeroCount, 2),
        "LastTick", 0,
        "Iter", 0,
        "AoaM", 0.01,
        "AoaB", 0,
        "DragM", 0.01,
        "DragB", 0,
        "Aoa", 0,
        "Thrust", 0,
        "ShouldUpdate", false,
        "LandingSpd", 0
    ).
}

function flightAeroUpdate {
    parameter aero, reality.

    local x to aero:In.
    local y to aero:Out.
    local i to aero:Iter.
    local nowTick to reality:time.
    set aero:LastTick to nowTick.
    set aero:Iter to mod(i + 1, kFlight:AeroCount).

    local totalThrust to 0.
    local engs to list().
    list engines in engs.
    for e in engs {
        set totalThrust to totalThrust + e:thrust. 
    }
    local thrustAccRaw to ship:facing:forevector * totalThrust / ship:mass.
    local gravAccRaw to gat(reality:Alt) * body:position:normalized.
    local aeroAccRaw to (reality:Acc - thrustAccRaw - gravAccRaw).
    local aeroAcc to reality:Pro:inverse * aeroAccRaw.
    local aeroforceDiff to aeroAcc * ship:mass.
    local aeroforce to aeroforceDiff.

    local lift to aeroforce:y.
    local drag to aeroforce:z.
    local cLift to lift / reality:Dyn.
    local cDrag to drag / reality:Dyn.

    klaSet(x, i + 1, 2, reality:Aoa).
    klaSet(y, i + 1, 1, cLift).
    klaSet(y, i + 1, 2, cDrag).    

    if i = kFlight:AeroCount - 1 {
        local solution to klaBackslash(x, y).
        set aero:AoaB to klaGet(solution, 1, 1).
        set aero:AoaM to klaGet(solution, 2, 1).
        set aero:DragB to klaGet(solution, 1, 2).
        set aero:DragM to klaGet(solution, 2, 2).

        local air2 to reality:Tas ^ 2.
        local Gmag to gat(reality:Alt) * ship:mass.
        local stallAngle to 10. // TODO incorporate zero lift angle
        local stallCl to aero:AoaM * stallAngle + aero:AoaB.
        local altFactor to body:atm:altitudepressure(reality:Alt)
            / body:atm:altitudepressure(100).
        local stallSpd to sgnsqrt(Gmag * altFactor * (air2 / reality:Dyn)
            / stallCl).

        set aero:LandingSpd to stallSpd.
        set aero:ShouldUpdate to true.
        // print "Performing Update " + aero.
    }


}

function flightLevelAoaLinear {
    parameter aero, reality, grav, vspd.
 
    local dyn to reality:Dyn.
    // local air to reality:Tas.
    // local vspd to reality:Vs.
    local hspd to reality:Gs.
    local air to sqrt(hspd ^ 2 + vspd ^ 2).
    local aoa to reality:Aoa.

    local sinP to vspd / air.
    local cosP to hspd / air.
    local Gmag to grav * ship:mass.
    local prevThrust to aero:Thrust.
    local GdotL to -Gmag * cosP.
    local GdotD to Gmag * sinP.

    local m to aero:AoaM.
    local b to aero:AoaB.
    local md to aero:DragM.
    local bd to aero:DragB.

    // small angle approximation of thrust * sin(aoa).
    local stable to ((-GdotL) / (dyn) - b) 
        / (m + constant:degtorad * prevThrust / dyn).
    // don't set aoa to more than 3 degrees off current
    set stable to aoa + clamp(stable - aoa, -3, 3).
    local stableDrag to -1 * (md * stable + bd) * dyn.
    local stableThrust to (1 / cos(stable)) * (stableDrag + GdotD).

    set aero:Aoa to stable.
    set aero:Thrust to stableThrust.
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
    flightRealityUpdate(params:reality, acc).
    flightAeroUpdate(params:aero, params:reality).
    flightLevelAoaLinear(params:aero, params:reality,
        rollGrav, vspd).
    local aoa to params:aero:Aoa.
    local thrust to params:aero:Thrust.
    local updateLandingSpd to params:aero:LandingSpd.
    if params:aero:ShouldUpdate and updateLandingSpd > 10 {
        set params:landV to stepLowpassUpdate(params:landV, updateLandingSpd,
            params:landVUpdateK).
        set params:aero:ShouldUpdate to false.
    }

    // PIDs
    local aoaPid to params:aoaPid.
    set aoaPid:setpoint to vspd.
    local aoaOffset to aoaPid:update(time:seconds, levelSurf:y).
    // calculate a throttle adjustment, but remember to count falling as -spd
    local throttlePid to params:throttlePid.
    set throttlePid:setpoint to hspd.
    local throtAdj to throttlePid:update(time:seconds, levelSurf:z).
    // print "a " + round(aoaOffset, 2) + " t " + round(throtAdj, 2) 
    //     + " A " + round(aoaOffset + aoa, 2).

    // noise to feed data to the flight model
    local pitchNoise to kPitchNoiseAmp * sin(360 * mod(time:seconds, 2)).

    // pitch
    local pitchA to arcTan2(vspd, hspd).
    local travel to flightPitch(pitchA).
    local aoaRots to flightPitch(aoa + aoaOffset + pitchNoise).
    local rolled to lookDirUp(unitZ, rollUp).
    local flight to travel * rolled * aoaRots.
    set params:steering to flight.

    // throttle
    local idealThrot to clamp(thrust / max(ship:maxThrust, 0.01), 0, 1).
    // Keep throttle above 0 to keep it ready for throttling up.
    // set throtAdj to 0.
    set params:throttle to max(idealThrot + throtAdj, 0.02).
}

function flightLanding {
    parameter params.

    set params:hspd to params:landV.
    // tried 5deg pitch for flare, but trying to rotate caused bouncing
    if status = "LANDED" {
        set params:throttle to 0.

        if params:landTime < 0 {
            set params:landTime to time:seconds.
        } else if time:seconds - params:landTime > 1 {
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

        set params:steering to params:level:inverse * facing.
        return.
    }
    set params:landTime to -1.

    local flaring to groundAlt() < kFlight:FlareHeight.
    // Flare changes both inputs --
    if flaring{
        set params:vspd to params:descentV / 2.
    }
    flightLevel(params).
    // -- and outputs
    if flaring {
        set params:throttle to 0.
    }
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
        lights on.
        brakes off.
        set params:landVUpdateK to 0.
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
        set params:landVUpdateK to params:levelUpdateK.
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

        setThrustReverser(kForward).
        set params:vspd to -1.
        setFlaps(3).
        brakes off.
        gear on.
        lights on.
        set params:landVUpdateK to params:landingUpdateK.
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
    set params:report:gui:x to -500.
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