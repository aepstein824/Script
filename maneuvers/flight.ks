@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

global kFlight to lexicon().
set kFlight:ThrotKp to 0.1. // Caps at even 1m/s off
set kFlight:AoAKp to 2. // 1 m/s vertical = X degree
set kFlight:Park to "PARK".
set kFlight:Takeoff to "TAKEOFF".
set kFlight:Level to "LEVEL".

// requires the far addon for info
local far to addons:far.

global flightParams to lexicon(
    // maintain
    "mode", kFlight:Park,
    "vspd", 0,
    "hspd", 43,
    "xacc", 0.0,

    // calculations
    "level", ship:facing,
    "throttlePid", flightThrottlePid(),
    "aoaPid", flightAoAPid(),

    // output
    "steering", ship:facing,
    "throttle", 0,

    // vis
    "arrowVec", v(0, 0, 0),

    // constants
    "takeoffV", 30,
    "takeoffAoA", 10,
    "takeoffHeading", 90
).
set flightParams:arrow to flightArrow(flightParams).

// flightCalcLevel().

function flightSteering {
    parameter params.

    if params:mode = "LEVEL" {
        // We have to recalc every time since we're spinning
        local out to -body:position.
        local lev to removeComp(velocity:surface, out).
        local level to lookDirUp(lev, out).
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
        local turnOmega to params:xacc / max(params:hspd, 10)
             * constant:radtodeg.
        local hack to r(0, turnOmega, 0).
        local steer to level * params:steering * hack.
        set params:arrowvec to steer:forevector.

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
    set params:level to lookDirUp(lev, out).

    if params:mode = kFlight:Takeoff {
        flightTakeoff(params).
    } else if params:mode = kFlight:Level {
        flightLevel(params).
    }
}

function flightTakeoff {
    parameter params.

    set params:steering to heading(params:takeoffHeading, params:takeoffAoA).
    set params:throttle to 1.
}

function flightLevel {
    parameter params.

    local level to params:level.
    
    local grav to gat(altitude).
    local liftFactor to sqrt(params:xacc^2 + grav^2) / grav.
    // Units of force, since aero doesn't care about mass
    local G to v(0, -1, 0) * grav * liftFactor * ship:mass.
    local presFactor to (far:ias / velocity:surface:mag) ^ 2.
    local levV to v(0, params:vspd, params:hspd).
    local levUp to v(params:xacc, grav, 0).
    // for now travel is a based on level
    local travel to lookDirUp(levV, v(0, 1, 0)).
    local travelV to travel:inverse * levV.
    local rolled to lookDirUp(levV, levUp).

    local levelSurf to level:inverse * velocity:surface.
    local aoaPid to params:aoaPid.
    set aoaPid:setpoint to params:vspd.
    local aoaOffset to aoaPid:update(time:seconds, levelSurf:y).

    local pitchInc to 5.
    local pitch to 0.
    local A to v(0, 0, 0).
    local T to v(0, 0, 0).
    local i to 0.
    local flight to facing.
    until false {
        local attackRot to flightEulerR(pitch, 0).
        local evalV to attackRot:inverse * travelV.

        local vSurf to facing * evalV.
        set A to attackRot * travel * facing:inverse 
            * far:aeroforceat(0, vSurf).
        set A to A * presFactor.
        set A:x to 0. // assume no side force
        set T to -1 * (A + G).

        local tPitch to vectorAngleAround(v(0, 0, 1), v(1, 0, 0), T).
        if tPitch > 180 {
            set tPitch to tPitch - 360.
        }
        // print "pitch: " + round(pitch, 3) + " tPitch: " + round(tPitch, 3).
        local diff to tPitch - pitch.
        if abs(diff) < .4 {
            // print "setting aoa to " + round(pitch, 3).
            local aoaRots to flightEulerR(pitch + aoaOffset, 0).
            local levFace to rolled * aoaRots * v(0, 0, 1).
            set flight to lookDirUp(levFace, levUp). 
            // set flight to level * rolled * attackRot.
            break.
        } else if diff > 0 {
            set pitch to pitch + pitchInc.
        } else {
            set pitch to pitch - pitchInc.
        }
        set pitchInc to pitchInc * 0.5.
        if i > 15 {
            print "Failed to find aero force, raising hspd".
            set params:hspd to params:hspd + 2.
            return.
        }
        set i to i + 1.
    }
    
    set params:steering to flight.

    // calculate a throttle adjustment, but remember to count falling as -spd
    local throttlePid to params:throttlePid.
    set throttlePid:setpoint to levV:z + 5 * levV:y.
    local signedSurf to levelSurf:z + 5 * levelSurf:y.
    local throtAdj to throttlePid:update(time:seconds, signedSurf).

    local idealThrot to T:mag / max(ship:maxThrust, 0.01).
    // Keep throttle above 0 to keep it ready for throttling up.
    set params:throttle to max(idealThrot + throtAdj, 0.05).
}

function flightEulerR {
    parameter pitch, slip.

    // args are right hand, R() is left hand
    return r(0, -slip, 0) * r(-pitch, 0, 0).
}

function flightCalcLevel {
    local out to -body:position.
    local lev to removeComp(facing:forevector, out).
    local level to lookDirUp(lev, out).
    local vSurf to velocity:surface.

    local vRaw to vSurf.

    local A to level:inverse * far:aeroforceat(0, vRaw).
    local Alevel to level:inverse * far:aeroforce.

    local atm to body:atm.

    local tas to vSurf:mag.
    local gamma to atm:adbidx.
    local staticPres to ship:sensors:pres * 1000.
    local temp to ship:sensors:temp.
    // rho is mass density = number density * molar mass
    // number density = p / RT
    local numberDensity to staticPres / constant:IdealGas / temp.
    local molarMass to atm:molarmass.
    local rho to numberDensity * molarMass.
    // a = sart(gamma * p / rho)
    local soundSpd to sqrt(gamma * staticPres / rho).
    local mach to tas / soundSpd.
    // q = M^2 * (1/2) * gamma * p
    // factor of 1000 to convert back to kpa
    local q to (mach ^ 2) * 0.5 * gamma * staticPres / 1000.
    // alternatively, q = 0.5 * rho * u^2
    local qq to 0.5 * rho * tas ^ 2 / 1000.

    local ias to tas / sqrt(1.225 / rho).

    local avgTemp to atm:altitudetemperature(0).
    local avgPres to atm:altitudepressure(0) * 1000 * constant:atmtokpa.
    local qFactor to (temp / avgTemp) ^ (-1) * (staticPres / avgPres).

    local ias_rat to tas / far:ias.
    local ias_qrat to ias_rat ^ 2.
    local ias_A to A / ias_qrat.

    clearall().
    print "speed of sound = " + soundSpd.
    print "rho = " + rho.
    print "avgTemp = " + avgTemp.
    print "avgPres = " + avgPres.
    print "q factor = " + qFactor.
    print "---".
    print "Alevel " + vecRound(Alevel, 2).
    print "Asense " + vecRound(A * qFactor, 2).
    print "A ias  " + vecRound(ias_A, 2).
    print "---".
    print "Guess Q " + q.
    print "Other Q " + qq.
    print "Check Q " + far:dynpres.
    print "---".
    print "Guess mach " + mach.
    print "Check mach " + far:mach.
    print "---".
    print "Guess IAS " + ias.
    print "Check IAS " + far:ias.

}

function flightBeginTakeoff {
    parameter params.

    if params:mode <> kFlight:Takeoff {
        set params:mode to kFlight:Takeoff.

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

        brakes off.
        gear off.
    }
}

function flightThrottlePid {
    local pid to pidloop(kFlight:ThrotKp, 0, 0).
    set pid:maxoutput to 0.1.
    set pid:minoutput to -0.1.
    return pid.
}

function flightAoAPid {
    local pid to pidloop(kFlight:AoAKp, 0, 0).
    set pid:maxoutput to 1.
    set pid:minoutput to -1.
    return pid.
}