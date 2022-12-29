@LAZYGLOBAL OFF.

clearscreen.

runOncePath("0:common/geo.ks").
runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/phasing.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/flight.ks").
runOncePath("0:maneuvers/hover.ks").
runOncePath("0:phases/airline").

set kPhases:startInc to 0.
set kPhases:stopInc to 0.

// local runway to waypoint("island 09").
// local runway to waypoint("ksc 09").
// local runway to waypoint("ksc 27").
local runway to waypoint("Cove Launch Site").
local takeoffHeading to 90.
local landHeading to 0.
local glideAngle to 3.
local turnXacc to 4.
local endRadius to 3.
local vtol to true.
local vtolLandDistance to 500.

local hovering to vtol.
local flightParams to flightDefaultParams().
local hoverParams to hoverDefaultParams().

airportInit().
airportTakeoff().
airportLoop().
airportLanding().

function airportInit {
    stageToMax().
    clearAll().
    flightSetSteeringManager().
    flightCreateReport(flightParams).
    brakes on.
}

function airportSwitchToFlight {
    lock steering to flightSteering(flightParams).
    lock throttle to flightThrottle(flightParams).
    set hovering to false.
}

function airportSwitchToHover {
    lock steering to hoverSteering(hoverParams).
    lock throttle to hoverThrottle(hoverParams).
    set hovering to true.
}

function airportFlightTakeoff {
    print "Begin takeoff".

    airportSwitchToFlight().

    set flightParams:takeoffHeading to takeoffHeading.
    flightBeginTakeoff(flightParams).
    until groundAlt() > 50 {
        airportIterWait().
    }
    print "Achieved takeoff, vspd " + verticalSpeed.

    flightBeginLevel(flightParams).
    setFlaps(1).
    set flightParams:hspd to flightParams:maneuverV.

    local startLevel to time:seconds.
    set flightParams:vspd to 1.8.
    until  time:seconds - startLevel > 5 {
        airportIterWait().
    }
}

function airportHoverTakeoff {
    print "Vertical takeoff".

    set hoverParams:mode to kHover:Hover.
    set hoverParams:tgt to runway:geoposition.
    airportSwitchToHover().
    
    local startHover to time:seconds.
    until time:seconds - startHover > 10 {
        airportIterWait().
    }

    hoverHoverToFlight().

    set flightParams:landV to 50.
    set flightParams:maneuverV to 60.
    set flightParams:cruiseV to 80.

    print flightParams.

    airportSwitchToFlight().

    flightBeginLevel(flightParams).
    setFlaps(1).
    set flightParams:hspd to flightParams:maneuverV.
}

function airportTakeoff {
    if vtol {
        airportHoverTakeoff().
    } else {
        airportFlightTakeoff().
    }
}

function airportLoop {
    local approachDist to 200 * flightParams:landV.
    local approachH to sin(glideAngle) * approachDist.
    local approachAlt to runway:altitude + approachH.

    local nowRadius to flightSpdToRadius(groundspeed, turnXacc).
    local landRadius to flightSpdToRadius(flightParams:maneuverV + 5, turnXacc).

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

    until path:empty() {
        set flightParams:vspd to airlineCruiseVspd(approachAlt, altitude, 3).

        set approachFrame to geoNorthFrame(runwayApproachGeo).
        set nowPos to -runwayApproachGeo:position.
        set nowPos2d to noY(approachFrame:inverse * nowPos).
        set nowDir to approachFrame:inverse * flightParams:level.
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
            set flightParams:xacc to airlineStraightErrorToXacc(app, apv).
        } else if path[0][0] = "turn" {
            local turn to path[0][2].
            local turnError to airlineTurnError(path[0][2], nowPos2d, nowVel).
            local dimlessR to (nowPos2d - turn:p):mag / turn:r.
            local nowXacc to flightSpdToXacc(groundspeed, turn:r).
            set flightParams:xacc to airlineTurnErrorToXacc(turnError, dimlessR,
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
    flightBeginLanding(flightParams).
    local runwayGeo to runway:geoposition.
    local runwayAlt to 5.
    until groundspeed < 1 {
        local runwayPos to runwayGeo:position.
        local runwayLev to flightParams:level:inverse * runwayPos
            + runwayAlt * unitY.

        if vtol and runwayLev:mag < vtolLandDistance {
            break.
        }
        if runwayLev:z > 10 {
            // approaching runway
            local tanTheta to 1.5 * runwayLev:y / runwayLev:z.
            local descent to groundspeed * tanTheta.
            // local desLimit to max(5, groundspeed/10).
            // set flightParams:vspd to max(descent, -desLimit).
            set flightParams:vspd to descent.

            local approach to heading(landHeading, 0).
            // negative
            local app to approach:inverse * runway:position.
            local apv to approach:inverse * velocity:surface.
            // print vecRound(app, 2).
            // print closeFactor.
            set flightParams:xacc to airlineStraightErrorToXacc(app, apv).

        } else {
            // close to or past runway
            set flightParams:vspd to flightParams:descentV.
            set flightParams:xacc to 0.
        }

        airportIterWait().
    }

    if vtol  {
        hoverFlightToHover().
        airportSwitchToHover().
        
        wait 10.
        set hoverParams:seek to true.

        until runwayGeo:position:mag < hoverParams:minAGL * 2 {
            airportIterWait().
        } 

        set hoverParams:vspdCtrl to -2.
        set hoverParams:mode to kHover:Vspd.

        until status = "LANDED" {
            airportIterWait().
        }
    }
}

function airportIterWait {
    if hovering {
        hoverIter(hoverParams).
    } else {
        flightIter(flightParams).
    }
    wait 0.05.
}