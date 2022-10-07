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

local params to flightParams.

airlineInit().
airlineTakeoff().
airlineLoop().
airlineLanding().

function airlineInit {
    stageToMax().
    flightSetSteeringManager().
    lock steering to flightSteering(params).
    lock throttle to flightThrottle(params).
    brakes on.
}

function airlineTakeoff {
    print "Begin takeoff".
    set params:takeoffHeading to landHeading.
    flightBeginTakeoff(params).
    until groundAlt() > 50 {
        airlineIterWait().
    }
    print "Achieved takeoff, vspd " + verticalSpeed.
}

function airlineLoop {
    flightBeginLevel(params).

    local startLevel to time:seconds.
    set params:vspd to 1.8.
    until  time:seconds - startLevel > 5 {
        airlineIterWait().
    }

    print "Uturn starting heading " + compass().
    set params:vspd to 0.
    until abs(compass() - uturnHeading) < 1 {
        if abs(compass() - uturnHeading) < 10 {
            set params:xacc to -2.
        } else {
            set params:xacc to -4.
        }
        airlineIterWait().
    }
    set params:xacc to 0.
    set params:vspd to 1.

    local approach to heading(landHeading, 0).
    print "Back down runway".
    until vdot(runway:position, approach:forevector) > 5000 {
        // print "Down runway " + vdot(runway:position, approach:forevector).
        airlineIterWait().
    }
    print "Far from runway, current heading " + round(compass(), 1).

    set params:vspd to 0.
    print "Land starting heading " + compass().
    until abs(compass() - landHeading) < 1 {
        if abs(compass() - landHeading) < 10 {
            set params:xacc to -2.
        } else {
            set params:xacc to -4.
        }
        airlineIterWait().
    }
    set params:xacc to 0.
}

function airlineLanding {
    flightBeginLanding(params).
    until groundspeed < 1 {
        local runwayLev to params:level:inverse * runway:position. 
        if runwayLev:z > 10 {
            // approaching runway
            local tanTheta to runwayLev:y / runwayLev:z.
            local descent to params:hspd * tanTheta.
            set params:vspd to max(descent, -5).

            local approach to heading(landHeading, 0).
            // negative
            local apv to approach:inverse * velocity:surface.
            local app to approach:inverse * runway:position.
            local tgtX to 3 * apv:z * app:x / app:z.
            local xdiff to tgtX - apv:x.
            set params:xacc to clamp(xdiff, -2, 2).
        } else {
            // close to or past runway
            set params:vspd to params:descentV.
            set params:xacc to 0.
        }

        airlineIterWait().
    }
}

function airlineIterWait {
    flightIter(params).
    wait 0.1.
}