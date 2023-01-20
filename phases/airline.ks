@LAZYGLOBAL OFF.

runOncePath("0:common/geo.ks").
runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/flight.ks").
runOncePath("0:maneuvers/hover.ks").

global kAirline to lexicon().
set kAirline:DiffToVspd to 1.0 / 30.
set kAirline:MaxTurnAngle to 30.
set kAirline:TurnR to 0.1.
set kAirline:Runway to waypoint("ksc 09").
set kAirline:TakeoffHeading to 90.
set kAirline:LandHeading to 90.
set kAirline:Vtol to vang(facing:forevector, up:forevector) < 30.
set kAirline:GlideAngle to 3.
set kAirline:TurnXacc to 4.
set kAirline:EndRadius to 3.
set kAirline:VtolLandDistance to 500.
set kAirline:FlightP to flightDefaultParams().
set kAirline:HoverP to hoverDefaultParams().
set kAirline:CruiseAlt to 7000.
set kAirline:LandAggro to 2.
set kAirline:VspdAng to 10.
set kAirline:FinalS to 100.

local hovering to kAirline:Vtol.

function airlineInit {
    stageToMax().
    flightSetSteeringManager().
    flightCreateReport(kAirline:FlightP).
    if status = "LANDED" {
        brakes on.
    }
}

function airlineCruiseVspd {
    parameter tgtAlt, curAlt, limAngle.
    local lim to groundspeed * sin(limAngle).
    local vDiff to tgtAlt - curAlt.
    return clamp(vDiff * kAirline:DiffToVspd, -lim, lim).
}

function airlineTurnError {
    parameter turn, pos2d, v2d.
    local posC to pos2d - turn:p.
    local radDiff to posC:mag - turn:r.
    local inside to radDiff < 0.
    local posO to posC.
    if inside {
        set posO to posC:normalized * (turn:r - radDiff). 
    }
    local posO2d to posO + turn:p.
    local tgt2d to turnIntersectPoint(turn, posO2d).
    local error to vectorAngleAround(v2d, unitY, tgt2d - posO2d).
    if inside {
        set error to -1 * error.
    }
    return smallAng(error).
}

function airlineTurnErrorToXacc {
    parameter error, dimlessR, turnXacc, ccw.

    local errorX to clamp(-error / kAirline:MaxTurnAngle, -1, 1). 

    local rDist to dimlessR - 1.
    if rDist < kAirline:TurnR {
        return (choose -1 if ccw else 1) * turnXacc + errorX.
    }
    return errorX * (turnXacc + 1).
}

function airlineStraightErrorToXacc {
    parameter app, apv.
    local closeFactor to lerp(app:z/1000, 0.1, 3).
    local tgtX to closeFactor * apv:z * app:x / app:z.
    local xdiff to tgtX - apv:x.
    return clamp(xdiff, -1, 1).
}

function airlineSwitchToFlight {
    lock steering to flightSteering(kAirline:FlightP).
    lock throttle to flightThrottle(kAirline:FlightP).
    set hovering to false.
}

function airlineSwitchToHover {
    lock steering to hoverSteering(kAirline:HoverP).
    lock throttle to hoverThrottle(kAirline:HoverP).
    set hovering to true.
}

function airlineFlightTakeoff {
    print "Begin takeoff".

    airlineSwitchToFlight().

    set kAirline:FlightP:takeoffHeading to kAirline:TakeoffHeading.
    flightBeginTakeoff(kAirline:FlightP).
    until groundAlt() > 50 {
        airlineIterWait().
    }
    print "Achieved takeoff".

    flightBeginLevel(kAirline:FlightP).
    setFlaps(1).
    set kAirline:FlightP:hspd to kAirline:FlightP:maneuverV.

    local startLevel to time:seconds.
    set kAirline:FlightP:vspd to 1.8.
    until  time:seconds - startLevel > 5 {
        airlineIterWait().
    }
}

function airlineHoverTakeoff {
    print "Vertical takeoff".

    set kAirline:HoverP:mode to kHover:Hover.
    set kAirline:HoverP:tgt to kAirline:Runway:geoposition.
    airlineSwitchToHover().
    
    local startHover to time:seconds.
    until time:seconds - startHover > 10 {
        airlineIterWait().
    }

    hoverHoverToFlight().

    set kAirline:FlightP:landV to 50.
    set kAirline:FlightP:maneuverV to 60.
    set kAirline:FlightP:cruiseV to 80.

    print kAirline:FlightP.

    airlineSwitchToFlight().

    flightBeginLevel(kAirline:FlightP).
    setFlaps(1).
    set kAirline:FlightP:hspd to kAirline:FlightP:maneuverV.
}

function airlineTakeoff {
    if kAirline:Vtol {
        airlineHoverTakeoff().
    } else {
        airlineFlightTakeoff().
    }
}

function airlineLoop {
    local approachDist to kAirline:FinalS * kAirline:FlightP:maneuverV.
    local approachH to sin(kAirline:GlideAngle) * approachDist.
    local approachAlt to kAirline:Runway:altitude + approachH.

    local nowRadius to flightSpdToRadius(groundspeed, kAirline:turnXacc).
    local landRadius to flightSpdToRadius(kAirline:FlightP:maneuverV + 5, 
        kAirline:turnXacc).

    local runwayApproachGeo to geoApproach(kAirline:Runway, 
        kAirline:LandHeading, -approachDist).
    local approachFrame to geoNorthFrame(runwayApproachGeo).

    local nowVel to noY(approachFrame:inverse * velocity:surface). 
    local nowPos to -runwayApproachGeo:position.
    local nowPos2d to noY(approachFrame:inverse * nowPos) + 3 * nowVel.
    local nowDir to lookDirUp(nowVel, unitY).

    local path to turnPointToPoint(nowPos2d, nowRadius, nowDir, 
        zeroV, landRadius, r(0,kAirline:LandHeading,0)).
    path:remove(0).

    until path:empty() {
        set kAirline:FlightP:vspd to airlineCruiseVspd(
            approachAlt, altitude, kAirline:VspdAng).

        set approachFrame to geoNorthFrame(runwayApproachGeo).
        set nowPos to -runwayApproachGeo:position.
        set nowPos2d to noY(approachFrame:inverse * nowPos).
        set nowDir to approachFrame:inverse * kAirline:FlightP:level.
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
            // print "P2d " + vecround(nowPos2d) 
            //     + " along " + vecround(along)
            //     + " App " + vecround(app)
            //     + " Apv " + vecround(apv).
            set kAirline:FlightP:xacc to airlineStraightErrorToXacc(app, apv).
            local endRad to (kAirline:EndRadius * groundspeed).
            if (nowPos2d - path[0][1]):mag  < endRad {
                path:remove(0).
            }
        } else if path[0][0] = "turn" {
            local turn to path[0][2].
            local turnError to airlineTurnError(turn, nowPos2d, nowVel).
            local dimlessR to (nowPos2d - turn:p):mag / turn:r.
            local nowXacc to flightSpdToXacc(groundspeed, turn:r).
            set kAirline:FlightP:xacc to airlineTurnErrorToXacc(turnError, 
                dimlessR, nowXacc, turnCCW(turn)).
            local outDir to vcrs(path[0][1] - turn:p, turn:d:upvector).
            local dev to vang(nowVel, outDir).
            // print "P2d " + vecround(nowPos2d) 
            //     + " toOut " + vecround(path[0][1])
            //     + " turnError " + round(turnError)
            //     + " dimlessR " + round(dimlessR, 2)
            //     + " nowXacc " + round(nowXacc, 1)
            //     + " devation " + dev.
            if dev < 2 {
                path:remove(0).
            }
        }

        airlineIterWait().

        
    }
}

function airlineLanding {
    flightBeginLanding(kAirline:FlightP).
    local runwayGeo to kAirline:Runway:geoposition.
    local runwayAlt to 5 + runwayGeo:terrainHeight.
    local tanGlideAngle to tan(-1 * kAirline:GlideAngle).
    local remainder to 5 * kAirline:FlightP:maneuverV.
    until groundspeed < 1 {
        // approaching runway
        local approach to heading(kAirline:LandHeading, 0).
        local app to approach:inverse * runwayGeo:altitudeposition(runwayAlt).

        if kAirline:Vtol and app:mag < kAirline:VtolLandDistance {
            break.
        }
        if app:z > remainder {
            local roundKerbin to body:radius * vectorAngleR(
                -body:position,
                runwayGeo:position - body:position
            ).
            local altDiff to altitude - runwayAlt.
            local tanToRunway to (-altDiff / roundKerbin).
            local tanTheta to tanGlideAngle
                + kAirline:LandAggro * (tanToRunway - tanGlideAngle).
            local descent to groundspeed * tanTheta.
            // print "tanToRunway " + round(groundspeed * tanToRunway, 2)
            //     + " tanGlideAngle " + round(groundspeed * tanGlideAngle, 2)
            //     + " roundKerbin " + round(roundKerbin, 2)
            //     + " altDiff " + round(altDiff, 2).
            set kAirline:FlightP:vspd to descent.

            local apv to approach:inverse * velocity:surface.
            set kAirline:FlightP:xacc to airlineStraightErrorToXacc(app, apv).

        } else {
            // close to or past runway
            set kAirline:FlightP:vspd to kAirline:FlightP:descentV.
            set kAirline:FlightP:xacc to 0.
        }

        airlineIterWait().
    }

    if kAirline:Vtol {
        hoverFlightToHover().
        airlineSwitchToHover().
        
        wait 10.
        set kAirline:HoverP:seek to true.

        until runwayGeo:position:mag < kAirline:HoverP:minAGL * 2 {
            airlineIterWait().
        } 

        set kAirline:HoverP:vspdCtrl to -2.
        set kAirline:HoverP:mode to kHover:Vspd.

        until status = "LANDED" {
            airlineIterWait().
        }
    }
}

function airlineIterWait {
    if hovering {
        hoverIter(kAirline:HoverP).
    } else {
        flightIter(kAirline:FlightP).
    }
    wait 0.05.
}
