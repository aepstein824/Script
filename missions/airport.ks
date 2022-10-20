@LAZYGLOBAL OFF.

clearscreen.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/phasing.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/flight.ks").

set kPhases:startInc to 0.
set kPhases:stopInc to 0.

local runway to waypoint("ksc 09").
local uturnHeading to 270.
local landHeading to 90.

local params to defaultFlightParams.

airportInit().
airportTakeoff().
airportLoop().
airportLanding().

function airportInit {
    stageToMax().
    clearAll().
    flightSetSteeringManager().
    flightCreateReport(params).
    lock steering to flightSteering(params).
    lock throttle to flightThrottle(params).
    brakes on.
}

function airportTakeoff {
    print "Begin takeoff".
    set params:takeoffHeading to landHeading.
    flightBeginTakeoff(params).
    until groundAlt() > 50 {
        airportIterWait().
    }
    print "Achieved takeoff, vspd " + verticalSpeed.
}

function airportLoop {
    flightBeginLevel(params).
    setFlaps(1).
    set params:hspd to params:maneuverV.

    local startLevel to time:seconds.
    set params:vspd to 1.8.
    until  time:seconds - startLevel > 5 {
        airportIterWait().
    }

    print "Uturn starting heading " + compass().
    set params:vspd to 0.
    until abs(compass() - uturnHeading) < 1 {
        airportVControl(params, 350).
        if abs(compass() - uturnHeading) < 10 {
            set params:xacc to -2.
        } else {
            set params:xacc to -4.
        }
        airportIterWait().
    }

    set params:xacc to 0.
    local approach to heading(landHeading, 0).
    print "Back down runway".
    until vdot(runway:position, approach:forevector) > 5000 {
        // print "Down runway " + vdot(runway:position, approach:forevector).
        airportVControl(params, 350).
        airportIterWait().
    }
    print "Far from runway, current heading " + round(compass(), 1).

    set params:vspd to 0.
    print "Land starting heading " + compass().
    set params:hspd to params:maneuverV.
    until abs(compass() - landHeading) < 1 {
        airportVControl(params, 350).
        if abs(compass() - landHeading) < 10 {
            set params:xacc to -2.
        } else {
            set params:xacc to -4.
        }
        airportIterWait().
    }
    set params:xacc to 0.
}

function airportLanding {
    flightBeginLanding(params).
    until groundspeed < 1 {
        local runwayLev to params:level:inverse * runway:position. 
        if runwayLev:z > 10 {
            // approaching runway
            local tanTheta to runwayLev:y / runwayLev:z.
            local descent to params:hspd * tanTheta.
            local desLimit to min(5, groundspeed/10).
            set params:vspd to max(descent, -desLimit).

            local approach to heading(landHeading, 0).
            // negative
            local apv to approach:inverse * velocity:surface.
            local app to approach:inverse * runway:position.
            local closeFactor to lerp(app:z/1000, 0.1, 3).
            // print vecRound(app, 2).
            // print closeFactor.
            local tgtX to closeFactor * apv:z * app:x / app:z.
            local xdiff to tgtX - apv:x.
            set params:xacc to clamp(xdiff, -1, 1).
        } else {
            // close to or past runway
            set params:vspd to params:descentV.
            set params:xacc to 0.
        }

        airportIterWait().
    }
}

function airportVControl {
    parameter params, alti.
    local vDiff to alti - altitude.
    set params:vspd to clamp(vDiff / 30, -3, 3).
}

function airportIterWait {
    flightIter(params).
    wait 0.1.
}