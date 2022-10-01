@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

global kFlight to lexicon().
set kFlight:ThrotKp to 0.04. // 0.2 for every 5m/s off
set kFlight:Park to "PARK".
set kFlight:Takeoff to "TAKEOFF".
set kFlight:Level to "LEVEL".

// requires the far addon for info
local far to addons:far.

global flightParams to lexicon(
    // maintain
    "mode", kFlight:Park,
    "vspd", 0,
    "hspd", 30,
    "pitchTrim", 0, // degrees

    // calculations
    "level", ship:facing,
    "throttlePid", flightThrottlePid(),

    // output
    "steering", ship:facing,
    "throttle", 0,

    // vis
    "arrowVec", v(0, 0, 0),

    // constants
    "takeoffV", 30,
    "takeoffAoA", 10,
    "takeoffHeading", 90,
    "cruiseAoA", 2,
    "cruiseThrottle", 0.2,
    "trimPerSecond", 0.5
).
set flightParams:arrow to flightArrow(flightParams).

// flightCalcLevel().

function flightSteering {
    parameter params.

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
    local lev to removeComp(facing:forevector, out).
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

    local out to -body:position.
    local lev to removeComp(facing:forevector, out).
    local level to lookDirUp(lev, out).

    // Units of force, since aero doesn't care about mass
    local G to v(0, -1, 0) * gat(altitude) * ship:mass.
    local presFactor to (far:ias / velocity:surface:mag) ^ 2.
    local levV to v(0, params:vspd, params:hspd).
    // for now travel is a based on level
    local travel to lookDirUp(levV, v(0, 1, 0)).
    local travelV to travel:inverse * levV.

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

        local levFace to attackRot * levV:normalized.
        set params:arrowVec to level * levFace.

        local tPitch to vectorAngleAround(v(0, 0, 1), v(1, 0, 0), T).
        if tPitch > 180 {
            set tPitch to tPitch - 360.
        }
        // print "pitch: " + round(pitch, 3) + " tPitch: " + round(tPitch, 3).
        local diff to tPitch - pitch.
        if abs(diff) < .5 {
            // print "setting aoa to " + round(pitch, 3).
            local rawFace to level * attackRot * levV.
            set flight to lookDirUp(rawFace, level:upvector). 
            break.
        } else if diff > 0 {
            set pitch to pitch + pitchInc.
        } else {
            set pitch to pitch - pitchInc.
        }
        set pitchInc to pitchInc * 0.5.
        if i > 15 {
            // print "exit pitch: " + round(pitch, 3)
                // + " tPitch: " + round(tPitch, 3).
            return.
        }
        set i to i + 1.
    }
    
    set params:steering to flight.

    local throttlePid to params:throttlePid.
    set throttlePid:setpoint to levV:mag.
    local idealThrot to T:mag / max(ship:maxThrust, 0.01).
    local throtAdj to throttlePid:update(time:seconds, velocity:surface:mag).
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

    if params:mode <> kFlight:Level {
        set params:mode to kFlight:Level.

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