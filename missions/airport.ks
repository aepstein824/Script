@LAZYGLOBAL OFF.

clearscreen.

runOncePath("0:common/geo.ks").
runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/phasing.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/flight.ks").
runOncePath("0:phases/airline").

set kPhases:startInc to 0.
set kPhases:stopInc to 0.

// local runway to waypoint("island 09").
local runway to waypoint("island 09").
local landHeading to 90.
local glideAngle to 3.
local turnXacc to 4.
local endRadius to 100.

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

    flightBeginLevel(params).
    setFlaps(1).
    set params:hspd to params:maneuverV.

    local startLevel to time:seconds.
    set params:vspd to 1.8.
    until  time:seconds - startLevel > 5 {
        airportIterWait().
    }
}

function airportLoop {
    local approachDist to 60 * params:landV.
    local approachH to sin(glideAngle) * approachDist.
    local approachAlt to runway:altitude + approachH.

    local nowRadius to flightSpdToRadius(params:maneuverV + 5, turnXacc).
    local landRadius to flightSpdToRadius(params:maneuverV + 5, turnXacc).

    local runwayNorthFrame to geoNorthFrame(runway).
    local runwayApproachGeo to geoApproach(runway, landHeading, 
        -approachDist).
    local approachFrame to geoNorthFrame(runwayApproachGeo).

    local nowPos to -runwayApproachGeo:position.
    local nowPos2d to noY(approachFrame:inverse * nowPos).
    local nowVel to noY(approachFrame:inverse * velocity:surface). 
    local nowDir to lookDirUp(nowVel, unitY).
    local nowTurn to turnFromPoint(nowPos2d, nowDir, nowRadius, -1).
    local landTurn to turnFromPoint(zeroV, r(0,landHeading,0), landRadius, -1).

    local path to turnToTurn(nowTurn, landTurn).
    path:remove(0).
    print path.

    until path:empty() {
        set params:vspd to airlineCruiseVspd(approachAlt, altitude, 3).

        local approachFrame to geoNorthFrame(runwayApproachGeo).
        local nowPos to -runwayApproachGeo:position.
        local nowPos2d to noY(approachFrame:inverse * nowPos).
        local nowDir to approachFrame:inverse * params:level.
        local nowVel to noY(approachFrame:inverse * velocity:surface). 

        local path2d to path[0][1].

        if path[0][0] = "straight" or path[0][0] = "start" {
            // there will always be a turn after the straight
            local turn to path[1][2].
            local fromCenter to (path2d - turn:p):normalized.
            local along to rotateVecAround(fromCenter, turn:d:upvector, 90).
            local towards to lookDirUp(along, turn:d:upvector).
            local app to towards:inverse * (path2d - nowPos2d).
            local apv to towards:inverse * nowVel.
            print "P2d " + vecround(nowPos2d) 
                + " along " + vecround(along)
                + " App " + vecround(app)
                + " Apv " + vecround(apv).
            set params:xacc to airlineStraightErrorToXacc(app, apv).
        } else if path[0][0] = "turn" {
            local turn to path[0][2].
            local turnError to airlineTurnError(path[0][2], nowPos2d, nowVel).
            local dimlessR to (nowPos2d - turn:p):mag / turn:r.
            local nowXacc to flightSpdToXacc(groundspeed, turn:r).
            set params:xacc to airlineTurnErrorToXacc(turnError, dimlessR,
                nowXacc, true).
            print "P2d " + vecround(nowPos2d) 
                + " toOut " + vecround(path[0][1])
                + " turnError " + round(turnError)
                + " dimlessR " + round(dimlessR, 2)
                + " nowXacc " + round(nowXacc, 1).
        }

        airportIterWait().

        if (nowPos2d - path[0][1]):mag  < endRadius {
            path:remove(0).
        }


    }
}

function airportLanding {
    flightBeginLanding(params).
    until groundspeed < 1 {
        local runwayLev to params:level:inverse * runway:position. 
        if runwayLev:z > 10 {
            // approaching runway
            local tanTheta to 1.5 * runwayLev:y / runwayLev:z.
            local descent to groundspeed * tanTheta.
            local desLimit to min(5, groundspeed/10).
            set params:vspd to max(descent, -desLimit).

            local approach to heading(landHeading, 0).
            // negative
            local app to approach:inverse * runway:position.
            local apv to approach:inverse * velocity:surface.
            // print vecRound(app, 2).
            // print closeFactor.
            set params:xacc to airlineStraightErrorToXacc(app, apv).

        } else {
            // close to or past runway
            set params:vspd to params:descentV.
            set params:xacc to 0.
        }

        airportIterWait().
    }
}

function airportIterWait {
    flightIter(params).
    wait 0.05.
}