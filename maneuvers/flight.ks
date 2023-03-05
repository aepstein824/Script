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
set kFlight:AeroCount to 100.
set kFlight:FlareHeight to 8.
set kFlight:hAccKp to 1.
set kFlight:hAccMax to 20.
set kFlight:vAccKp to 1.
set kFlight:vAccMax to 20.
set kFlight:TurnMax to 45.

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
        "vacc", 0.0,
        "hacc", 0.0,

        // calculations
        "differ", flightDifferCreate(),
        "reality", flightRealityCreate(),
        "model", flightModelCreate(),
        "control", flightControlCreate(),
        "hAccPid", flightHAccPid(),
        "vAccPid", flightVAccPid(),
        "landV", 65,
        "landVUpdateK", 0,

        // output
        "steering", ship:facing,
        "throttle", 0,
        "shouldTransform", false,

        // vis
        "arrowVec", v(0, 0, 0),
        "report", false,

        // constants
        "takeoffAoA", 8,
        "takeoffHeading", 90,
        "landingUpdateK", 0.04,
        "levelUpdateK", 0.1,
        "maneuverV", 100,
        "cruiseV", 250,
        "descentV", -2,
        "landTime", -1
    ).
    // local arrow to flightArrow(params).
    // set params:arrow to arrow.
    return params.
}

function flightSteering {
    parameter params.

    if params:shouldTransform {
        flightDifferUpdate(params:differ).

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
        local turnHack to angleAxis(turnOmega, up:vector).
        local proUp to lookDirUp(velocity:surface, up:vector).
        local steer to  turnHack * proUp * params:steering.

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

    if not params:report:istype("BOOLEAN") {
        for k in params:report:keyToVal:keys {
            set params:report["keyToVal"][k]:text 
                to round(params[k], 2):tostring().
        }
    }

    set params:shouldTransform to false.

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
        "Bank", 0,
        "Dyn", 1E-10,
        "Surf", zeroV,
        "Grav", 0,
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
    set reality:Aoa to vang(vxcl(facing:rightvector, reality:Surf),
        facing:upvector) - 90.
    set reality:Bank to vang(facing:rightvector, up:vector) - 90.
    set reality:Dyn to max(ship:dynamicpressure, 1E-10).
    set reality:Grav to gat(altitude) - centrip(velocity:orbit:mag, altitude).
    set reality:Acc to acc.
    set reality:Time to time:seconds.
    set reality:Alt to altitude.
    set reality:Pro to lookDirUp(reality:Surf, facing:upvector).
}

function flightModelCreate {
    return lexicon(
        "LiftLinReg", linearRegressionCreate(kFlight:AeroCount),
        "DragLinReg", linearRegressionCreate(kFlight:AeroCount),
        "LiftM", 0.01,
        "LiftB", 0,
        "DragM", 0.01,
        "DragB", 0,
        "UpdateLandingSpd", false,
        "LandingSpd", 0
    ).
}

function flightModelUpdate {
    parameter model, reality.

    local thrustAccRaw to ship:facing:forevector * ship:thrust / ship:mass.
    local gravAccRaw to reality:Grav * body:position:normalized.
    local aeroAccRaw to (reality:Acc - thrustAccRaw - gravAccRaw).
    local aeroAcc to reality:Pro:inverse * aeroAccRaw.
    local aeroforce to aeroAcc * ship:mass.

    local lift to aeroforce:y.
    local drag to aeroforce:z.
    local cLift to lift / reality:Dyn.
    local cDrag to drag / reality:Dyn.
    local aoa to reality:Aoa.

    local liftLinReg to model:LiftLinReg.
    local dragLinReg to model:DragLinReg.
    linearRegressionUpdate(liftLinReg, aoa, cLift).
    linearRegressionUpdate(dragLinReg, aoa, cDrag).

    set model:AoaM to liftLinReg:m.
    set model:AoaB to liftLinReg:b.
    set model:DragM to dragLinReg:m.
    set model:DragB to dragLinReg:b.

    // stall speed is level flight at 10 degrees
    local stallAngle to 10. // TODO incorporate zero lift angle
    local stallCl to model:AoaM * stallAngle + model:AoaB.
    if stallCl > 1 {
        // A small boost to G to leave room for additional vertical accel
        local Gmag to reality:Grav * ship:mass * 1.05.
        local air2 to reality:Tas ^ 2.
        local altFactor to body:atm:altitudepressure(reality:Alt)
            / body:atm:altitudepressure(100).
        local stallSpd to sgnsqrt(Gmag * altFactor * (air2 / reality:Dyn)
            / stallCl).

        set model:LandingSpd to stallSpd.
        set model:UpdateLandingSpd to true.
    }
}

function flightControlCreate {
    return lexicon(
        "Aoa", 0,
        "Thrust", 0,
        "RollUp", zeroV:vec()
    ).
}

function flightControlUpdate {
    parameter control, model, reality, accel.
 
    local dyn to reality:Dyn.
    local air to reality:Tas.
    local vspd to reality:Vs.
    local hspd to reality:Gs.
    local aoa to reality:Aoa.

    local grav to reality:Grav.
    local cosP to hspd / air.
    local totalY to (accel:y + grav) / cosP.

    local maxTanTurn to tan(kFlight:TurnMax).
    local xacc to clampAbs(accel:x, abs(totalY) * maxTanTurn).

    local liftAcc to v(xacc, totalY, 0).
    local rollUp to liftAcc:vec.
    local sgnY to sgn(totalY).
    if sgnY < 0 {
        // In theory, we should roll the opposite way to get a turn while our
        // lift is negative. In practice, negative lift is only maintained for
        // short periods of time, and this kind of inverse roll just causes me
        // trouble.
        set liftAcc:x to 0.
        set rollUp to liftAcc * -1.
    }
    local liftMag to liftAcc:mag * ship:mass * sgnY.

    local nowThrust to ship:thrust.
    local reqLift to liftMag.

    local m to max(model:AoaM, 1).
    local b to model:AoaB.
    local md to model:DragM.
    local bd to model:DragB.

    // small angle approximation of thrust * sin(aoa).
    local stable to ((reqLift) / (dyn) - b) 
        / (m + constant:degtorad * nowThrust / dyn).
    // don't set aoa to more than some degrees off current
    set stable to aoa + clampAbs(stable - aoa, 5).

    local sinP to vspd / air.
    local liftDotDrag to liftMag * sinP.
    local stableDrag to -1 * (md * stable + bd) * dyn.
    local stableThrust to (1 / cos(stable)) * (ship:mass * accel:z 
        + stableDrag + liftDotDrag).

    set control:rollUp to rollUp.
    set control:Aoa to stable.
    set control:Thrust to stableThrust.
}

function flightLevel {
    parameter params.

    set params:shouldTransform to true.

    local vspd to params:vspd.
    local hspd to params:hspd.
    
    local hAccPid to params:HAccPid.
    set hAccPid:setpoint to hspd.
    local vAccPid to params:VAccPid.
    set vAccPid:setpoint to vspd.

    local desiredAccel to v(0, 0, 0).
    set desiredAccel:x to params:xacc.
    set desiredAccel:y to vAccPid:update(time:seconds, verticalSpeed).
    set desiredAccel:z to hAccPid:update(time:seconds, groundSpeed).

    local acc to params:differ:D[0].
    flightRealityUpdate(params:reality, acc).
    flightModelUpdate(params:model, params:reality).
    flightControlUpdate(params:control, params:model, params:reality,
        desiredAccel).
    
    local aoa to params:control:Aoa.
    local thrust to params:control:Thrust.
    local newLandingSpd to params:model:LandingSpd.
    if params:model:UpdateLandingSpd {
        set params:landV to stepLowpassUpdate(params:landV, newLandingSpd,
            params:landVUpdateK).
        set params:model:UpdateLandingSpd to false.
    }

    // noise to feed data to the flight model
    local pitchNoise to kPitchNoiseAmp * sin(360 * mod(time:seconds, 1) / 4).

    // pitch
    local aoaRots to flightPitch(aoa + pitchNoise).
    local rolled to lookDirUp(unitZ, params:control:rollUp).
    local flight to rolled * aoaRots.
    set params:steering to flight.

    // throttle
    // Keep throttle above 0 to keep it ready for throttling up.
    local idealThrot to clamp(thrust / max(ship:maxThrust, 0.02), 0, 1).
    set params:throttle to idealThrot.

    // For the report only
    set params:vacc to desiredAccel:y.
    set params:hacc to desiredAccel:z.
}

function flightLanding {
    parameter params.

    set params:hspd to params:landV.
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

        set params:steering to facing.
        return.
    }
    set params:landTime to -1.

    local flaring to groundAlt() < kFlight:FlareHeight.
    // We want to fly stably into the landing
    if flaring{
        set params:vspd to params:descentV / 2.
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

        flightResetSpds(params, params:cruiseV).
        setFlaps(0).
        setThrustReverser(kForward).
        brakes off.
        gear off.
        lights off.
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
        "vspd", "hspd", "xacc", "vacc", "hacc",
        "landV", "maneuverV", "cruiseV")).


    wait 0.
    set params:report:gui:x to -500.
    set params:report:gui:y to -300.
    params:report:gui:show().
}

function flightHAccPid {
    local kp to kFlight:HAccKp.
    // horizontal should not have I term 
    local pid to pidloop(kp, 0, kp / 5).
    set pid:minoutput to -kFlight:HAccMax.
    set pid:maxoutput to kFlight:HAccMax.
    return pid.
}

function flightVAccPid {
    local kp to kFlight:VAccKp.
    local pid to pidloop(kp, kp / 10, kp / 5).
    set pid:minoutput to -kFlight:VAccMax.
    set pid:maxoutput to kFlight:VAccMax.
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