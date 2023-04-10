@LAZYGLOBAL OFF.

runOncePath("0:common/geo.ks").
runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/flight.ks").
runOncePath("0:maneuvers/hover.ks").

global kAirline to lexicon().
set kAirline:DiffToVspd to 1.0 / 15.
set kAirline:MaxTurnAngle to 20.
set kAirline:MaxTurnAdjustment to 2.
set kAirline:MaxStraightAngle to 5.
set kAirline:TurnR to 0.1.
set kAirline:TakeoffHeading to 90.
set kAirline:Vtol to vang(facing:forevector, up:forevector) < 30.
set kAirline:GlideAngle to 5.
set kAirline:TurnXaccMult to 0.4.
set kAirline:EndRadius to 3.
set kAirline:VtolLandDistance to 500.
set kAirline:VlSpd to -2.
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

function airlineTo {
    parameter landWpt.
    local approachWpt to airlineWptApproach(landWpt).
    local approachGeo to approachWpt:geo.

    set kAirline:TakeoffHeading to shipHeading().
    airlineTakeoff(landWpt).

    set kuniverse:timewarp:mode to "PHYSICS".
    set kuniverse:timewarp:rate to 4.

    if geoBodyPosDistance(zeroV, approachGeo:position) > kAirline:CruiseDist {
        // local departWpt to airlineWptCreate(geoPosition, approachWpt:geo:heading,
        //     kAirline:CruiseAlti).

        // print "Turn to depart from current location".
        // airlineLoop(departWpt).
        print "Cruise to destination".
        airlineCruise(approachWpt).
    }

    set kuniverse:timewarp:rate to 3.

    if geoBodyPosDistance(zeroV, approachGeo:position) > kAirline:FlatDist {
        print "Short distance to approach".
        airlineShortHaul(approachWpt).
    }

    set kuniverse:timewarp:rate to 2.

    print "Go to approach".
    airlineLoop(approachWpt).
    print "Begin landing".
    airlineLanding(landWpt).
    print "Chill".
    lock steering to "KILL".
    lock throttle to 0.
    wait 3.
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
    local dimlessR to posC:mag / turn:rad.
    local dimlessROffset to dimlessR - 1.
    local error to 0.
    if abs(dimlessROffset) < kAirline:TurnR {
        local outDir to vcrs(posC, turn:d:upvector):normalized.
        set error to vectorAngleAround(v2d, unitY, outDir).
    } else {
        local radDiff to posC:mag - turn:rad.
        local inside to radDiff < 0.
        local posO to posC.
        if inside {
            set posO to posC:normalized * (turn:rad - radDiff). 
        }
        local posO2d to posO + turn:p.
        local tgt2d to turnIntersectPoint(turn, posO2d).
        set error to vectorAngleAround(v2d, unitY, tgt2d - pos2d).
    }

    return smallAng(error).
}

function airlineTurnErrorToXacc {
    parameter error, dimlessR, turnXacc, ccw.

    local errorX to clampAbs(-error / kAirline:MaxTurnAngle,
        kAirline:MaxTurnAdjustment).

    local rDist to dimlessR - 1.
    if abs(rDist) < kAirline:TurnR {
        return (choose -1 if ccw else 1) * (turnXacc + 20 * rDist) + errorX.
    }
    return errorX * (turnXacc + 1).
}

function airlineStraightErrorToXacc {
    parameter app, apv.
    local closeFactor to lerp(app:z/1000, 0.1, 3).
    local tgtX to closeFactor * apv:z * app:x / app:z.
    local xdiff to tgtX - apv:x.
    return clamp(xdiff, -2, 2).
}

function airlineSwitchToFlight {
    lock steering to flightSteering(kAirline:FlightP).
    lock throttle to flightThrottle(kAirline:FlightP).
    set hovering to false.
}

function airlineSwitchToHover {
    hoverLock(kAirline:HoverP).
    set hovering to true.

    set kAirline:HoverP:mode to kHover:Hover.
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

    set kAirline:FlightP:vspd to 1.8.
    repeatForDuration(airlineIterWait@, 5).
}

function airlineHoverTakeoff {
    print "Vertical takeoff".

    lights on.
    local startLiftoff to time:seconds.
    // point directly up but don't rotate, just to get off ground
    lock steering to lookDirUp(up:forevector, facing:upvector).
    lock throttle to 1.
    wait until time:seconds - startLiftoff > 10.
    print "Hovering".

    airlineSwitchToHover().
    // We want it to fall and then fly toward the target.
    set kAirline:HoverP:seek to true.
    set kAirline:HoverP:crab to false.

    local startHover to time:seconds.
    until time:seconds - startHover > 10 {
        airlineIterWait().
    }

    hoverHoverToFlight().

    airlineSwitchToFlight().

    flightBeginLevel(kAirline:FlightP).
    set kAirline:FlightP:hspd to kAirline:FlightP:maneuverV.
    local startLevel to time:seconds.
    until time:seconds - startLevel > 10 {
        airlineIterWait().
    }
}

function airlineTakeoff {
    parameter landWpt.
    if kAirline:Vtol {
        set kAirline:HoverP:tgt to landWpt:geo.
        airlineHoverTakeoff().
    } else {
        airlineFlightTakeoff().
    }
}

// Wpt stands for waypoint, but since "waypoint" is a bound name, I'm going to
// use exclusivly "wpt" in the code when referring to this structure.
function airlineWptCreate {
    parameter geo, hdg, alti to -10000.

    local useAlti to terrainHGeo(geo).
    if alti > useAlti {
        set useAlti to alti.
    }

    return lexicon (
        "geo", geo,
        "hdg", hdg,
        "alti", alti
    ).
}

// function airlineWptAddName {
//     parameter vesselName.
// }

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
    local approachAlt to terrainHGeo(runwayGeo) + approachH.

    local approachGeo to geoApproach(runwayGeo, landHeading, -approachDist).

    return airlineWptCreate(approachGeo, runwayWpt:hdg, approachAlt).

}

function airlineTurnXacc {
    parameter gAtSeaLevel.
    return kAirline:turnXAccMult * gAtSeaLevel.
}

function airlineGeoContext {
    parameter endGeo, pos, vel.

    local frame to geoNorthFrame(endGeo).
    local nowPos to pos - endGeo:position.
    local nowPos2dFlat to noY(frame:inverse * nowPos).
    local nowDist to geoBodyPosDistance(pos, nowPos).
    local nowPos2d to nowPos2dFlat:normalized * nowDist.

    local out to pos - body:position.
    local levelVel to vxcl(out, vel).
    local nowFore to noy(frame:inverse * levelVel:normalized).

    return lex(
        "frame", frame,
        "nowPos", nowPos,
        "nowPos2d", nowPos2d,
        "nowDist", nowDist,
        "nowFore", nowFore
    ).
}

function airlineLoop {
    parameter endWpt.

    local endGeo to endWpt:geo.
    local flightP to kAirline:FlightP.
    local maneuverSpd to FlightP:maneuverV.
    set kAirline:FlightP:hspd to maneuverSpd.

    local turnXacc to airlineTurnXacc(gat(0)).

    local nowRadius to flightSpdToRadius(maneuverSpd, turnXacc).
    local landRadius to flightSpdToRadius(maneuverSpd, turnXacc).

    local ctx to airlineGeoContext(endGeo, zeroV, velocity:surface).

    local flightPath to turnPointToPoint(
        ctx:nowPos2d, nowRadius, lookDirUp(ctx:nowFore, unitY), 
        zeroV, landRadius, r(0, endWpt:hdg, 0)).
    flightPath:remove(0).

    until flightPath:empty() {
        set FlightP:vspd to airlineCruiseVspd(
            endWpt:alti, altitude, kAirline:VspdAng).

        set ctx to airlineGeoContext(endGeo, zeroV, velocity:surface).

        local frame to ctx:frame.
        local nowPos2d to ctx:nowPos2d.
        local nowFore to ctx:nowFore.

        local path2d to flightPath[0][1].

        if flightPath[0][0] = "straight" or flightPath[0][0] = "start" {
            // there will always be a turn after the straight
            local turn to flightPath[1][2].
            local fromCenter to (path2d - turn:p):normalized.
            local along to vcrs(fromCenter, turn:d:upvector).
            local outHdg to posAng(arcTan2(along:x, along:z)).
            local pathGeo to geoNorth2dToGeo(endGeo, frame, path2d).
            local toHdg to pathGeo:heading.
            local desired to posAng(toHdg 
                + clampAbs(smallAng(toHdg - outHdg),90)).
            local hdgDiff to smallAng(desired - shipVHeading()).
            local hdgBased to airlineBearingXacc(hdgDiff, turnXacc).
            set flightP:xacc to hdgBased.
            local endRad to kAirline:EndRadius * groundspeed.
            local endDist to geoBodyPosDistance(zeroV, pathGeo:position).
            // print "P2d " + vecround(nowPos2d)
            //     + " toHdg " + round(toHdg)
            //     + " outHdg " + round(outHdg)
            //     + " desired " + round(desired)
            //     + " endDist " + round(endDist).
            if endDist < endRad {
                flightPath:remove(0).
            }
        } else if flightPath[0][0] = "turn" {
            local turn to flightPath[0][2].
            local turnError to airlineTurnError(turn, nowPos2d, nowFore).
            local dimlessR to (nowPos2d - turn:p):mag / turn:rad.
            local nowXacc to flightSpdToXacc(groundspeed, turn:rad).
            set FlightP:xacc to airlineTurnErrorToXacc(turnError, 
                dimlessR, nowXacc, turnCCW(turn)).
            local outDir to vcrs(path2d - turn:p, turn:d:upvector).
            local dev to vang(nowFore, outDir).
            // print "P2d " + vecround(nowPos2d) 
            //     + " toOut " + vecround(path2d)
            //     + " turnError " + round(turnError)
            //     + " dimlessR " + round(dimlessR, 2)
            //     + " nowXacc " + round(nowXacc, 1)
            //     + " devation " + dev.
            if dev < 1 {
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

    local runwayAlti to terrainHGeo(runwayGeo).
    local shallowS to 5.
    local extraOver to 7.
    local extraShallow to 7.
    local tanGlideAngle to -1 * tan(kAirline:GlideAngle).
    local descentV to flightP:descentV.
    local vtolS to 2.

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

        if app:z < vtolS * landV {
            // close to or past runway
            kuniverse:timewarp:cancelwarp(). 
            set flightP:xacc to 0.
        }

        if kAirline:Vtol and app:mag < kAirline:VtolLandDistance {
            kuniverse:timewarp:cancelwarp(). 
            set kAirline:hoverP:tgt to runwayGeo.
            break.
        }

        airlineIterWait().
    }

    if kAirline:Vtol {
        hoverFlightToHover().
        airlineSwitchToHover().
        print "Vtol Landing".
        
        set kAirline:HoverP:seek to true.
        repeatForDuration(airlineIterWait@, 5).
        set kAirline:HoverP:crab to true.
        print " Toward Lz".

        until vxcl(body:position, runwayGeo:position):mag
            < kAirline:HoverP:minAGL / 2 {
            airlineIterWait().
        } 

        set kAirline:HoverP:vspdCtrl to kAirline:VlSpd.
        set kAirline:HoverP:mode to kHover:Vspd.
        print " Descent".

        until shipIsLandOrSplash() {
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
    parameter endGeo, cruiseAlti, cruiseSpd, stopDist, optimize.

    local turnXacc to airlineTurnXacc(gat(0)).
    local printed to false.

    local lfI to 0.
    for i in range(ship:resources:length) {
        if ship:resources[i]:name = "LiquidFuel" {
            set lfI to i.
            break.
        }
    }
    local liquidFuel to ship:resources[lfI].
    local lfDensity to liquidFuel:density.
    local startFuel to liquidFuel:amount * lfDensity.
    local cruiseFuel to 0.
    local tanDescentAngle to tan(kAirline:VspdAng).

    local optimizeCtx to lex().
    if optimize {
        set optimizeCtx to cruiseContextCreate(cruiseAlti, cruiseSpd,
                0, 0, time:seconds).
    }

    local flightP to kAirline:FlightP.
    flightBeginLevel(flightP).
    setFlaps(0).
    until false {
        if optimize {
            local mpt to cruiseShipMpt().
            local throt to ship:thrust / ship:maxthrust.
            local now to time:seconds.
            local isSteady to cruiseCheckSteady(optimizeCtx, altitude, 
                groundspeed, verticalSpeed, throt, now).
            if isSteady {
                set optimizeCtx to cruiseSteadyUpdate(optimizeCtx, throt, mpt,
                    now).
                set cruiseAlti to optimizeCtx:alti.
                set cruiseSpd to optimizeCtx:spd.
            }
        }

        set flightP:hspd to cruiseSpd. 

        local endPos to endGeo:position.
        local endDist to geoBodyPosDistance(zeroV, endPos).
        if endDist > kAirline:CruiseDist {
            local altiAboveCruise to altitude - kAirline:CruiseAlti. 
            if altiAboveCruise > 0 {
                set endDist to endDist - altiAboveCruise / tanDescentAngle.
            }
        }

        local closeToEnd to endDist < stopDist.
        if closeToEnd {
            break.
        }
        set flightP:xacc to airlineBearingXacc(endGeo:bearing,
            turnXacc).

        local altiErr to altitude - cruiseAlti.
        local endAngle to arctan2(kAirline:CruiseAggro * altiErr, endDist).
        local altiAngLim to max(abs(endAngle), 10).
        set flightP:vspd to airlineCruiseVspd(cruiseAlti, altitude, altiAngLim).

        if not printed and abs(altiErr) < 30 {
            set printed to true.
            set cruiseFuel to liquidFuel:amount * lfDensity.
            print " Fuel to reach alti " + round(startFuel - cruiseFuel, 2).
        }

        airlineIterWait().
    }

    local destFuel to liquidFuel:amount * lfDensity.
    print " Fuel to reach dest " + round(startFuel - destFuel, 2).
}

function airlineCruise {
    parameter endWpt, optimize to true.

    local cruiseAlti to kAirline:CruiseAlti.
    airlineDirect(endWpt:geo, cruiseAlti, kAirline:FlightP:cruiseV,
        kAirline:CruiseDist, optimize).

    local flightP to kAirline:FlightP.

    until altitude < cruiseAlti + 100 {
        set flightP:vspd to airlineCruiseVspd(cruiseAlti, altitude, 10).
        airlineIterWait().
    } 

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

    airlineDirect(endWpt:geo, endWpt:alti, maneuverSpd, kAirline:FlatDist,
        false).
}

function airlineIterWait {
    if hovering {
        hoverIter(kAirline:HoverP).
    } else {
        flightIter(kAirline:FlightP).
    }
    wait 0.
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

global kCruise to lex(
    "AltiDown", 500,
    "AltiUpFast", 2000,
    "AltiUpSlow", 500,
    "AltiThrotSlow", 0.5,
    "AltiThrotLim", 0.7,
    "AltiThrotDesc", 0.85,
    "SpdChange", 5,
    "SpdDelay", 300
).

function cruiseContextCreate {
    parameter alti, spd, throt, mpt, now.

    return lex(
        "differ", differCreate(list(spd, throt), now),

        "lastMpt", mpt,
        "lastTime", now,
        "lastSpd", spd,

        "altiPeaked", false,
        "alti", alti, 

        "spdPeaked", false,
        "spd", spd
    ).
}

function cruiseShipMpt {
    local thrust to ship:thrust.
    if thrust <= 0 {
        return 1.
    }
    return groundspeed / (thrust / (ship:engines[0]:isp * constant:g0)).
}

function cruiseCheckSteady {
    parameter ctx, alti, spd, vspd, throt, now.

    differUpdate(ctx:differ, list(spd, throt), now).

    return (
        abs(vspd) < 0.5
        and abs(ctx:spd - spd) < 1
        and abs(ctx:alti - alti) < 10
        and abs(ctx:differ:D[1]) < 0.005
        and abs(ctx:differ:D[0]) < 0.005 
    ).
}

function cruiseSteadyUpdate {
    parameter ctx, throt, mpt, now. 

    if ctx:altiPeaked and ctx:spdPeaked 
        and now < ctx:lastTime + kCruise:SpdDelay {
        // don't update time
        return ctx.
    }

    local newCtx to ctx:copy().

    set newCtx:lastMpt to mpt.
    set newCtx:lastTime to now.
    set newCtx:lastSpd to ctx:spd.

    print " Mpt " + round(mpt).
    if throt > kCruise:AltiThrotLim {
        set newCtx:altiPeaked to true.
        set newCtx:spdPeaked to false.
        if throt > kCruise:AltiThrotDesc {
            set newCtx:alti to ctx:alti - kCruise:AltiDown.
            print " Peak alti, descending to " + newCtx:alti.
            return newCtx.
        } else if not ctx:altiPeaked {
            print " Peak alti, holding " + newCtx:alti.
            return newCtx.
        }
    }
    

    if ctx:spdPeaked {
        if not ctx:altiPeaked {
            set newCtx:spdPeaked to false.
            set newCtx:lastMpt to 0.
            if throt > kCruise:AltiThrotSlow {
                set newCtx:alti to ctx:alti + kCruise:AltiUpSlow.
            } else {
                set newCtx:alti to ctx:alti + kCruise:AltiUpFast.
            }
            print " Peak spd, climbing to " + newCtx:alti.
            return newCtx.
        } else {
            // alti peaked
            if mpt < ctx:lastMpt {
                set newCtx:spd to ctx:lastSpd.
                print " Peak spd, correcting back to " + newCtx:spd.
                return newCtx.
            } else {
                set newCtx:spd to ctx:spd - kCruise:SpdChange.
                print " Peak spd, checking lower speed " + newCtx:spd.
                return newCtx.
            }
        }
    } else {
        if mpt < ctx:lastMpt {
            set newCtx:spdPeaked to true.
            set newCtx:spd to ctx:lastSpd.
            print " Found peak spd, decelerating to " + newCtx:spd.
            return newCtx.
        } else {
            set newCtx:spd to ctx:spd + kCruise:SpdChange.
            print " Finding peak spd, accelerating to " + newCtx:spd.
            return newCtx.
        }
    }
}