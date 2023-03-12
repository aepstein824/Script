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
set kAirline:MaxStraightAngle to 5.
set kAirline:TurnR to 0.1.
set kAirline:TakeoffHeading to 90.
set kAirline:Vtol to vang(facing:forevector, up:forevector) < 30.
set kAirline:GlideAngle to 5.
set kAirline:TurnXacc to 4.
set kAirline:EndRadius to 3.
set kAirline:VtolLandDistance to 500.
set kAirline:FlightP to flightDefaultParams().
set kAirline:HoverP to hoverDefaultParams().
set kAirline:CruiseAlti to 7000.
set kAirline:CruiseDist to 45000.
set kAirline:FlatDist to 8500. // gives enough for any turn at 100 m/s
set kAirline:CruiseAggro to 1.2.
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
    parameter tgtAlt, curAlt, limAngle, gspd to groundspeed.
    local lim to gspd * sin(limAngle).
    local vDiff to tgtAlt - curAlt.
    return clamp(vDiff * kAirline:DiffToVspd, -lim, lim).
}

function airlineTurnError {
    parameter turn, pos2d, v2d.
    local posC to pos2d - turn:p.
    local radDiff to posC:mag - turn:rad.
    local inside to radDiff < 0.
    local posO to posC.
    if inside {
        set posO to posC:normalized * (turn:rad - radDiff). 
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
    set kAirline:FlightP:hspd to kAirline:FlightP:maneuverV.
    wait 2.
}

function airlineTakeoff {
    if kAirline:Vtol {
        airlineHoverTakeoff().
    } else {
        airlineFlightTakeoff().
    }
}

// Wpt stands for waypoint, but since "waypoint" is a bound name, I'm going to
// use exclusivly "wpt" in the code when referring to this structure.
function airlineWptCreate {
    parameter geo, hdg, alti to -10000.

    local useAlti to geo:terrainHeight.
    if alti > useAlti {
        set useAlti to alti.
    }

    return lexicon (
        "geo", geo,
        "hdg", hdg,
        "alti", alti
    ).
}

// Wpt refers to my struct, waypoint to the built in type.
function airlineWptFromWaypoint {
    parameter argWaypoint, argHeading, argAlti to -100000.


    return airlineWptCreate(
        argWaypoint:geoPosition,
        argHeading,
        argAlti
    ).
}

function airlineWptApproach {
    parameter runwayWpt.

    local runwayGeo to runwayWpt:geo.
    local landHeading to runwayWpt:hdg.

    local approachDist to kAirline:FinalS * kAirline:FlightP:maneuverV.
    local approachH to sin(kAirline:GlideAngle) * approachDist.
    local approachAlt to runwayGeo:terrainHeight + approachH.

    local approachGeo to geoApproach(runwayGeo, landHeading, -approachDist).

    return airlineWptCreate(approachGeo, runwayWpt:hdg, approachAlt).

}

function airlineLoop {
    parameter endWpt.

    local endGeo to endWpt:geo.
    local flightP to kAirline:FlightP.
    local maneuverSpd to FlightP:maneuverV.
    set kAirline:FlightP:hspd to maneuverSpd.
    
    local nowRadius to flightSpdToRadius(maneuverSpd, kAirline:turnXacc).
    local landRadius to flightSpdToRadius(maneuverSpd, kAirline:turnXacc).

    local approachFrame to geoNorthFrame(endGeo).
    local nowPos to -endGeo:position.
    local nowPos2d to noY(approachFrame:inverse * nowPos).
    local nowDir to approachFrame:inverse * shipLevel().
    local nowVel to noY(approachFrame:inverse * velocity:surface). 

    local flightPath to turnPointToPoint(nowPos2d, nowRadius, nowDir, 
        zeroV, landRadius, r(0, endWpt:hdg, 0)).
    flightPath:remove(0).

    until flightPath:empty() {
        set FlightP:vspd to airlineCruiseVspd(
            endWpt:alti, altitude, kAirline:VspdAng).

        set approachFrame to geoNorthFrame(endGeo).
        set nowPos to -endGeo:position.
        set nowPos2d to noY(approachFrame:inverse * nowPos).
        set nowDir to approachFrame:inverse * shipLevel().
        set nowVel to noY(approachFrame:inverse * velocity:surface). 

        local path2d to flightPath[0][1].

        if flightPath[0][0] = "straight" or flightPath[0][0] = "start" {
            // there will always be a turn after the straight
            local turn to flightPath[1][2].
            local fromCenter to (path2d - turn:p):normalized.
            local along to vcrs(fromCenter, turn:d:upvector).
            local outHdg to arcTan2(along:x, along:z).
            local pathGeo to body:geoPositionof(endGeo:position
                + approachFrame * path2d).
            local toHdg to pathGeo:heading.
            local desired to posAng(toHdg 
                + clampAbs(smallAng(toHdg - outHdg),90)).
            local hdgDiff to smallAng(desired - shipHeading()).
            local hdgBased to airlineBearingXacc(hdgDiff, kAirline:TurnXacc).
            set flightP:xacc to hdgBased.
            local endRad to (kAirline:EndRadius * groundspeed).
            if (nowPos2d - path2d):mag  < endRad {
                flightPath:remove(0).
            }
        } else if flightPath[0][0] = "turn" {
            local turn to flightPath[0][2].
            local turnError to airlineTurnError(turn, nowPos2d, nowVel).
            local dimlessR to (nowPos2d - turn:p):mag / turn:rad.
            local nowXacc to flightSpdToXacc(groundspeed, turn:rad).
            set FlightP:xacc to airlineTurnErrorToXacc(turnError, 
                dimlessR, nowXacc, turnCCW(turn)).
            local outDir to vcrs(path2d - turn:p, turn:d:upvector).
            local dev to vang(nowVel, outDir).
            // print "P2d " + vecround(nowPos2d) 
            //     + " toOut " + vecround(path2d)
            //     + " turnError " + round(turnError)
            //     + " dimlessR " + round(dimlessR, 2)
            //     + " nowXacc " + round(nowXacc, 1)
            //     + " devation " + dev.
            if dev < 2 {
                flightPath:remove(0).
            }
        }

        airlineIterWait().
    }
}

function airlineLandY {
    parameter runwayAlti, shallowS, extraOver, extraShallow, tanGlide, landV, 
        descentV, z.

    local function resultCreate {
        parameter y, spd.
        return lex("y", y, "spd", spd).
    }

    if z < 0 {
        return resultCreate(0, descentV).
    }

    local landT to z / landV.

    local overAlti to runwayAlti + extraOver.
    local shallowZ to shallowS * landV. 

    if z < shallowZ {
        return resultCreate(overAlti - landT * descentV, descentV).
    }

    local shallowAlti to overAlti + extraShallow - shallowS * descentV.
    local glideT to landT - shallowS.
    local glideV to tanGlide * landV.

    return resultCreate(shallowAlti - glideV * glideT, glideV).
}

function airlineLanding {
    parameter runwayWpt.

    local flightP to kAirline:FlightP.
    flightBeginLanding(flightP).

    local runwayGeo to runwayWpt:geo.
    local landHeading to runwayWpt:hdg.

    local runwayAlti to  runwayGeo:terrainHeight.
    local shallowS to 5.
    local extraOver to 5.
    local extraShallow to 7.
    local tanGlideAngle to -1 * tan(kAirline:GlideAngle).
    local descentV to flightP:descentV.

    until groundspeed < 1 {
        local approach to heading(landHeading, 0).
        local app to approach:inverse
                * runwayGeo:altitudeposition(runwayAlti).
        local dist to geoBodyPosDistance(zeroV, runwayGeo:position)
            * sgn(app:z).
        local landV to flightP:landV.

        local glide to airlineLandY(runwayAlti, shallowS, extraOver,
            extraShallow, tanGlideAngle, landV, descentV, dist).
        local glideSpd to glide:spd.

        if dist > 0 {
            local errorV to airlineCruiseVspd(glide:y, altitude, 1).
            set glideSpd to glideSpd + errorV.
        }

        set flightP:vspd to glideSpd.

        local apv to approach:inverse * velocity:surface.
        set flightP:xacc to airlineStraightErrorToXacc(app, apv).

        if app:z < 200 {
            // close to or past runway
            kuniverse:timewarp:cancelwarp(). 
            set flightP:xacc to 0.
        }

        if kAirline:Vtol and app:mag < kAirline:VtolLandDistance {
            break.
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

function airlineBearingXacc {
    parameter brg, lim.

    local scaledBearing to brg / kAirline:MaxStraightAngle.
    return clampAbs(scaledBearing , lim).
}

function airlineDirect {
    parameter endGeo, cruiseAlti, cruiseSpd, stopDist.

    local flightP to kAirline:FlightP.
    flightBeginLevel(flightP).
    setFlaps(0).
    set flightP:hspd to cruiseSpd. 
    until false {
        local endPos to endGeo:position.
        local endDist to geoBodyPosDistance(zeroV, endPos).

        local movingToEnd to vdot(velocity:surface, endPos) > 0.
        local closeToEnd to endDist < stopDist.
        if (closeToEnd or not movingToEnd) {
            break.
        }
        set flightP:xacc to airlineBearingXacc(endGeo:bearing,
            kAirline:TurnXacc).

        local altiErr to altitude - cruiseAlti.
        local endAngle to arctan2(kAirline:CruiseAggro * altiErr, endDist).
        local altiAngLim to max(abs(endAngle), 10).
        set flightP:vspd to airlineCruiseVspd(cruiseAlti, altitude, altiAngLim).

        airlineIterWait().
    }
}

function airlineCruise {
    parameter endWpt.
    airlineDirect(endWpt:geo, kAirline:CruiseAlti, kAirline:FlightP:cruiseV,
        kAirline:CruiseDist).

    local flightP to kAirline:FlightP.
    setFlaps(1).
    flightResetSpds(flightP, flightP:maneuverV).
    until groundSpeed < flightP:maneuverV * 1.1 {
        airlineIterWait().
    } 
    setFlaps(0).
}

function airlineShortHaul {
    parameter endWpt.
    local flightP to kAirline:FlightP.
    local maneuverSpd to flightP:maneuverV.

    airlineDirect(endWpt:geo, endWpt:alti, maneuverSpd, kAirline:FlatDist).
}

function airlineIterWait {
    if hovering {
        hoverIter(kAirline:HoverP).
    } else {
        flightIter(kAirline:FlightP).
    }
    wait 0.05.
}


// Wpts
set kAirline:Wpts to lex(
    "Dessert00", airlineWptCreate(
        kerbin:geopositionlatlng(-6.6, -144.04088), 0),
    "Dessert18", airlineWptCreate(
        kerbin:geopositionlatlng(-6.45, -144.04088), 180),
    "Ksc09", airlineWptCreate(
        kerbin:geopositionlatlng(-0.048588, -74.729730), 90),
    "Ksc27", airlineWptCreate(
        kerbin:geopositionlatlng(-0.048588, -74.487785), 270),
    "Island09", airlineWptCreate(
        kerbin:geopositionlatlng(-1.518067, -71.968652), 90),
    "Island27", airlineWptCreate(
        kerbin:geopositionlatlng(-1.515664, -71.85139), 270),
    "NP27", airlineWptCreate(
        kerbin:geopositionlatlng(80, -100), 270)
).