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
    airlineTakeoff(approachWpt).

    set kuniverse:timewarp:mode to "PHYSICS".
    set kuniverse:timewarp:rate to 4.

    if geoBodyPosDistance(zeroV, approachGeo:position) > kAirline:CruiseDist {
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

function airlineBearingXacc {
    parameter brg, lim.

    local scaledBearing to brg / kAirline:MaxStraightAngle.
    return clampAbs(scaledBearing, lim).
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

    hoverSwitchMode(kAirline:HoverP, kHover:Hover).
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

function airlineWptFromVesselName {
    parameter vesselName.

    local baseVessel to vessel(vesselName).
    local baseGeo to baseVessel:geoposition.
    local baseHdg to posAng(180 + geoHeadingTo(baseGeo, geoPosition)).
    local baseWpt to airlineWptCreate(baseGeo, baseHdg).
    set baseWpt:vesselName to vesselName.
    
    return baseWpt.
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

        set ctx to airlineGeoContext(endGeo, zeroV, velocity:surface).

        local frame to ctx:frame.
        local path2d to flightPath[0][1].

        if flightPath[0][0] = "straight" or flightPath[0][0] = "start" {
            // there will always be a turn after the straight
            local turn to flightPath[1][2].
            local fromCenter to (path2d - turn:p):normalized.
            local along to vcrs(fromCenter, turn:d:upvector).
            local outHdgEnd to posAng(arcTan2(along:x, along:z)).
            local outHdgBeacon to geoBeacon(endGeo, outHdgEnd).
            local outGeo to geoNorth2dToGeo(endGeo, frame, path2d).
            local outHdgOut to geoHeadingTo(outGeo, outHdgBeacon).

            local outArrow to vecdraw(zeroV, {
                return outGeo:altitudeposition(altitude).},
                rgb(0,1,1), "Out", 0.1, true, 1.0).

            airlineLoopStraight(outGeo, outHdgOut, endWpt:alti, flightP).

            set outArrow:show to false.

            flightPath:remove(0).
        } else if flightPath[0][0] = "turn" {
            local turn to flightPath[0][2].
            local turnGeo to geoNorth2dToGeo(endGeo, frame, turn:p).
            local outGeo to geoNorth2dToGeo(endGeo, frame, path2d).
            local turnFinishHdg to geoHeadingTo(turnGeo, outGeo).
            local turnSign to choose -1 if turnCCW(turn) else 1.

            local centerArrow to vecdraw(zeroV, {
                return turnGeo:altitudeposition(altitude).},
                rgb(1,0,0), "Turn", 0.1, true, 1.0).
            local outArrow to vecdraw(zeroV, {
                return outGeo:altitudeposition(altitude).},
                rgb(0,1,1), "Out", 0.1, true, 1.0).

            airlineLoopTurn(turnGeo, turn:rad, turnSign, turnFinishHdg,
                endWpt:Alti, flightP).

            set centerArrow:show to false.
            set outArrow:show to false.

            // airlineLoopTurn(endGeo, path2d, endWpt:Alti, turn, flightP).
            flightPath:remove(0).
        }

        airlineIterWait().
    }
}

function airlineLoopStraight {
    parameter outGeo, outHdg, endAlti, flightP.

    local turnXacc to airlineTurnXacc(gat(0)).

    print " Straight".

    until false {
        set flightP:vspd to airlineCruiseVspd(
            endAlti, altitude, kAirline:VspdAng).

        local reverseHdg to geoHeadingTo(outGeo, geoPosition).
        local hdgError to smallAng(reverseHdg - outHdg - 180).
        local toHdg to outGeo:heading.
        local desired to posAng(toHdg + clampAbs(hdgError, 90)).
        local hdgDiff to smallAng(desired - shipVHeading()).
        local hdgXacc to airlineBearingXacc(hdgDiff, turnXacc).
        set flightP:xacc to hdgXacc.

        local outRad to kAirline:EndRadius * groundspeed.
        local outDist to geoBodyPosDistance(zeroV, outGeo:position).

        if outDist < outRad {
            return.
        }

        airlineIterWait().
    }
}

function airlineLoopTurn {
    parameter turnGeo, turnRad, turnSign, turnFinishHdg, endAlti, flightP.

    local turnXacc to airlineTurnXacc(gat(0)).

    print " Turn".

    until false {
        set FlightP:vspd to airlineCruiseVspd(
            endAlti, altitude,kAirline:VspdAng).

        local dist to geoBodyPosDistance(turnGeo:position, zeroV).
        local dimlessRad to dist / turnRad.

        local baseXacc to 0.
        if abs(dimlessRad - 1) < kAirline:TurnR {
            set baseXacc to turnSign * flightSpdToXacc(groundspeed, dist).
        }
        local tgtHdg to 0.

        if dimlessRad > 1 {
            local offsetMag to arcsin(min(1 / dimlessRad, .9999)).
            set tgtHdg to posAng(turnGeo:heading - turnSign * offsetMag).
        } else {
            local offsetMag to arcsin(min(dimlessRad, .9999)).
            set tgtHdg to posAng(180 + turnGeo:heading + turnSign * offsetMag).
        }
        local hdgDiff to smallAng(tgtHdg - shipVHeading()).
        local hdgXacc to airlineBearingXacc(hdgDiff, turnXacc).
        set flightP:xacc to baseXacc + hdgXacc.

        local turnFromHdg to geoHeadingTo(turnGeo, geoPosition).
        // print "Dimless R  " + round(dimlessRad, 3)
        //     + "  |  tgtHdg  " + round(tgtHdg, 1)
        //     + "  |  xacc  " + round(flightP:xacc, 1)
        //     + "  |  turnFromHdg  " + round(turnFromHdg)
        //     + "  |  turnFinishHdg  " + round(turnFinishHdg).

        local remainingAround to abs(turnFromHdg - turnFinishHdg).
        if remainingAround < 1 or remainingAround > 359 {
            return.
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
            if runwayWpt:haskey("vesselName") {
                local baseVessel to vessel(runwayWpt:vesselName).
                set kAirline:hoverP:tgt to getPort(baseVessel).
            } else {
                set kAirline:hoverP:tgt to runwayGeo.
            }
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
        hoverSwitchMode(kAirline:HoverP, kHover:Vspd).
        print " Descent".

        until shipIsLandOrSplash() {
            airlineIterWait().
        }
    }
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

    print "  Descending from cruise alti".
    until altitude < cruiseAlti + 100 {
        set flightP:vspd to airlineCruiseVspd(cruiseAlti, altitude, 10).
        airlineIterWait().
    } 

    print "  Slowing from cruise spd".
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
        kerbin:geopositionlatlng(80, -100), 270),
    "NP", airlineWptCreate(kerbin:geopositionlatlng(90, 0), 0)
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