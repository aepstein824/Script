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
// local runway to waypoint("ksc 09").
local runway to waypoint("ksc 27").
local takeoffHeading to 90.
local landHeading to 270.
local glideAngle to 3.
local turnXacc to 4.
local endRadius to 3.

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
    set params:takeoffHeading to takeoffHeading.
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

    local nowRadius to flightSpdToRadius(groundspeed, turnXacc).
    local landRadius to flightSpdToRadius(params:maneuverV + 5, turnXacc).

    local runwayApproachGeo to geoApproach(runway, landHeading, 
        -approachDist).
    local approachFrame to geoNorthFrame(runwayApproachGeo).

    local nowVel to noY(approachFrame:inverse * velocity:surface). 
    local nowPos to -runwayApproachGeo:position.
    local nowPos2d to noY(approachFrame:inverse * nowPos) + 3 * nowVel.
    local nowDir to lookDirUp(nowVel, unitY).

    local path to turnPointToPoint(nowPos2d, nowRadius, nowDir, 
        zeroV, landRadius, r(0,landHeading,0)).
    path:remove(0).
    print path.

    until path:empty() {
        set params:vspd to airlineCruiseVspd(approachAlt, altitude, 3).

        set approachFrame to geoNorthFrame(runwayApproachGeo).
        set nowPos to -runwayApproachGeo:position.
        set nowPos2d to noY(approachFrame:inverse * nowPos).
        set nowDir to approachFrame:inverse * params:level.
        set nowVel to noY(approachFrame:inverse * velocity:surface). 

        local path2d to path[0][1].

        if path[0][0] = "straight" or path[0][0] = "start" {
            // there will always be a turn after the straight
            local turn to path[1][2].
            local fromCenter to (path2d - turn:p):normalized.
            local along to rotateVecAround(fromCenter, turn:d:upvector, 90).
            local towards to lookDirUp(along, unitY).
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
                nowXacc, turnCCW(turn)).
            print "P2d " + vecround(nowPos2d) 
                + " toOut " + vecround(path[0][1])
                + " turnError " + round(turnError)
                + " dimlessR " + round(dimlessR, 2)
                + " nowXacc " + round(nowXacc, 1).
        }

        airportIterWait().

        if (nowPos2d - path[0][1]):mag  < (endRadius * groundspeed) {
            path:remove(0).
        }
    }
}

function airportLanding {
    flightBeginLanding(params).
    local runwayGeo to runway:geoposition.
    local runwayAlt to 5.
    until groundspeed < 1 {
        local runwayPos to runwayGeo:position.
        local runwayLev to params:level:inverse * runwayPos + runwayAlt * unitY.
        if runwayLev:z > 10 {
            // approaching runway
            local tanTheta to 1.5 * runwayLev:y / runwayLev:z.
            local descent to groundspeed * tanTheta.
            // local desLimit to max(5, groundspeed/10).
            // set params:vspd to max(descent, -desLimit).
            set params:vspd to descent.

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