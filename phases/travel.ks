@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:phases/rndv.ks").

global kTravelMatchThreshold to 0.01.

global stratIntercept to "INTERCEPT".
global stratSatellite to "SATELLITE_PLANEOF".
global stratEscapeTo to "ESCAPE_TOWARDS".
global stratEscape to "ESCAPE".
global stratLand to "LAND".
global stratLaunch to "LAUNCH".
global stratOrbiting to "ORBITING".
global stratMatch to "MATCH".

function travelTo {
    parameter ctx.

    sas off.
    local dest to ctx:dest.

    until false {
        local strat to travelStratTo(dest).
        print strat.

        if strat[0] = stratOrbiting {
            if not ctx:haskey("match") {
                break.
            }
            if travelObtsMatch(ship:obt, ctx:match:it:obt) {
                break.
            }
            travelMatch(ctx).
        }
        if strat[0] = stratIntercept {
            travelIntercept(ctx).
            break.
        }
        if strat[0] = stratEscape {
            travelEscape().
        }
        if strat[0] = stratEscapeTo {
            if strat:length = 2 {
                travelEscapeTo(ctx, strat[1], strat[1]).
            } else {
                travelEscapeTo(ctx, strat[1], strat[2]).
            }
        }
        if strat[0] = stratSatellite {
            travelSatellite(ctx, strat[1], strat[2]).
        }
        if strat[0] = stratLand {
            travelLandOn(ctx).
            break.
        }
        if strat[0] = stratLaunch {
            travelLaunch(ctx).
        }
    }
}

function travelStratTo {
    parameter targetable.

    if shipIsLandOrSplash() {
        return list(stratLaunch).
    }

    local ourBodies to list().
    local bodyIter to body.
    until bodyIter = sun {
        ourBodies:add(bodyIter).
        set bodyIter to bodyIter:obt:body.
    }
    ourBodies:add(sun).

    if ourBodies:find(targetable) <> -1 {
        if targetable = body {
            return list(stratOrbiting).
        }
        return list(stratEscape).
    }

    local tgtBodies to list().
    local tgtBodyIter to targetable.
    local ourIdx to ourBodies:length - 1.
    local tgtIsBody to true.
    if targetable:typename <> "BODY" {
        set tgtBodyIter to targetable:obt:body.
        set tgtIsBody to false.
        tgtBodies:add(targetable).
    }
    print "Traveling from " + body:name + " to " + tgtBodyIter:name.
    until false {
        tgtBodies:add(tgtBodyIter).
        local idx to ourBodies:find(tgtBodyIter).
        if idx <> -1 {
            set ourIdx to idx.
            break.
        }
        set tgtBodyIter to tgtBodyIter:obt:body.
    }

    // TgtBodies always ends in the common body.
    local tgtLen to tgtBodies:length.
    print tgtBodies.
    if ourIdx = 0 {
        if tgtBodies:length = 2 {
            if not tgtIsBody and targetable:status = "LANDED" {
                return list(stratLand).
            }
            return list(stratIntercept).
        } else  {
            return list(stratSatellite, tgtBodies[tgtLen - 2],
                tgtBodies[tgtLen - 3]).
        } 
    } 
    if ourIdx = 1 {
        if tgtBodies:length = 2 {
            return list(stratEscapeTo, tgtBodies[0]).
        } else  {
            return list(stratEscapeTo, tgtBodies[tgtLen - 2],
                tgtBodies[tgtLen - 3]).
        } 
    }
    if ourIdx > 1 {
        return list(stratEscape).
    }
}

function travelIntercept {
    parameter ctx.

    set target to ctx:dest:name.
    wait 0.
    local tgt to target.

    local safeHeight to atmHeightOr0(body) + 50000.
    if periapsis < safeHeight and tgt:obt:periapsis > safeHeight {
        print " Raise periapsis to " + safeHeight.
        circleNextExec(safeHeight).
    }

    local hl to travelDoubleHl(tgt).

    if tgt:typename = "BODY" {
        travelIntoSatOrbit(ctx, tgt, hl:arrivalTime).
        travelCaptureToInc(ctx).
    } else {
        local closestTime to closestApproach(ship, tgt).
        local tgtV to velocityAt(tgt, closestTime):orbit.
        local shipV to velocityAt(ship, closestTime):orbit.
        local diff to (tgtV - shipV):mag.
        local timeToDV to shipTimeToDV(diff).
        local timeBefore to timeToDV * 2 + 10.
        waitWarp(closestTime - 300).
        print " Warping to " + (closestTime - timeBefore).
        waitWarp(closestTime - timeBefore).
        doubleBallistic().
    }
}

function travelEscape {
    if orbitPatchesInclude(obt, body:body) {
        waitWarp(time:seconds + orbit:nextpatcheta + 60).
        return.
    }
    // 100 is an arbitrary threshold to split moons from planets
    if obt:inclination > 5 and obt:period > 100 {
        // wait for it to line up 
    }
    escapePrograde(1.3 * obtMinEscape(body, apoapsis)).
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}

function travelEscapeTo {
    parameter ctx, tgtBody, planeOf.

    if orbitPatchesInclude(obt, body:body) {
        waitWarp(time:seconds + orbit:nextpatcheta + 60).
        return.
    }

    orbitCircleAtAp().

    local hl to hlIntercept(body, tgtBody, lexicon("ignorePlane", true)).
    set hl:dest to tgtBody.
    if ship:obt:inclination < 2 and apoapsis < body:radius {
        print " Escaping using a slow burn".
        orbitSlowEscape(hl:burnVec, hl:start).
    } else {
        print " Escaping using an impulse burn".
        escapeOmni(hl).
        nodeExecute().
    }

    print " Waiting in travelEscapeTo to escape " + body:name.
    waitWarp(time:seconds + orbit:nextpatcheta + 60).

    travelIntoSatOrbit(ctx, tgtBody, hl:arrivalTime).
    if planeOf = tgtBody {
        travelCaptureToInc(ctx).
    } else {
        travelCaptureToPlaneOf(ctx, planeOf).
    }
}

function travelSatellite {
    parameter ctx, tgtBody, planeOf.

    local hl to travelDoubleHl(tgtBody).
    travelIntoSatOrbit(ctx, tgtBody, hl:arrivalTime).
    travelCaptureToPlaneOf(ctx, planeOf).
}

function travelIntoSatOrbit {
    parameter ctx, tgtBody, arrivalTime.

    // Change argument to travel time
    // change to refinement
    // allow for grid square as argument
    // print out the grid again for validation

    for i in range(3) {
        if orbit:hasnextpatch() and orbit:nextpatch:body = tgtBody and i > 0 {
            break.
        }
        local arrivalDuration to detimestamp(arrivalTime - time).
        local shipPos to positionAt(ship, arrivalTime).
        local tgtPos to positionAt(tgtBody, arrivalTime).
        local relDistance to (shipPos - tgtPos):mag / tgtBody:soiradius.
        if relDistance < 0.8 {
            print " Distance / soi " + round(relDistance, 2) + " at "
                + timeRoundStr(arrivalTime).
            print " Intercept will happen, but it isn't recorded as a patch".
            waitWarp(detimestamp(time + (arrivalDuration / 2))).
        } else {
            print " Refining Intercept (i = " + i + ")".
            local cc to courseCorrect(tgtBody, arrivalDuration).
            set arrivalTime to cc:arrivalTime.
            nodeExecute().
        }
    }

    print " Waiting in travelIntoSatOrbit".
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}

function travelCaptureToInc {
    parameter ctx.
    print "Capture into orbit around " + body:name.

    if not ctx:haskey("altitude") {
        print " Using default altitude".
        set ctx:altitude to opsScienceHeight(body).
    }
    if not ctx:haskey("inclination") {
        print " Using default inclination".
        set ctx:inclination to 0.
    }
    local norm to inclinationToNorm(ctx:inclination).
    entryPe(ctx:altitude + 500, norm).
    nodeExecute().
    if periapsis < ctx:altitude {
        entryPe(ctx:altitude + 500, norm).
        nodeExecute().
    }
    circleNextExec(ctx:altitude).
}

function travelCaptureToPlaneOf {
    parameter ctx, tgt.

    local norm to normOf(tgt:obt).
    local margin to 0.
    if (tgt:typename = "BODY") {
        set margin to 1.3 * tgt:soiradius.
    } else {
        set margin to 0.1 * tgt:obt:semimajoraxis.
    }
    local pe to tgt:obt:semimajoraxis + margin.
    entryPe(pe, norm).
    nodeExecute().
    circleNextExec(periapsis).
}

function travelDoubleHl {
    parameter targetable, options to lexicon().

    // The function may return a plane change instead.
    local hl to hlIntercept(ship, targetable, options).
    add hl:burnNode.
    nodeExecute().

    if hl:haskey("planes") and hl:planes {
        print " Retrying HL intercept after plane change".
        set options to mergeLex(options, lex("ignorePlane", true)).
        set hl to hlIntercept(ship, targetable, options).
        add hl:burnNode.
        nodeExecute().
    }

    return hl.
}

function travelLandOn {
    parameter ctx.
    local dest to ctx:dest.
    print "Landing".
    local geo to dest:geoposition.
    vacDescendToward(geo).
    lights on.
    vacLandGeo(geo, list(dest)).
    print " Landed at " + ship:geoposition.
}

function travelLaunch {
    parameter ctx.

    lights off.
    print " Lifting off " + body:name.

    local dest to ctx:dest.
    if dest:obt:body = body {
        local alti to 1.1 * dest:altitude.
        waitForTargetPlane(dest).
        wait 1.
        vacClimb(alti, launchHeading()).
        circleNextExec(alti).
    } else {
        local alti to opsScienceHeight(body).
        vacClimb(alti).
        circleNextExec(alti).
    }
}

function travelMatch {
    parameter ctx.

    local dest to ctx:match:it.
    print " Hl to match " + dest.
    local hlOptions to lexicon("obtLead", ctx:match:offset).
    local hl to travelDoubleHl(dest, hlOptions).

    print " Course correct to " + dest.
    set hl to courseCorrect(hl:dest, detimestamp(hl:arrivalTime - time),
        hlOptions).
    nodeExecute().

    print " Match orbit".
    local matchTransform to obtRnpFromPV(hl:p2, hl:vatp2).
    local matchBurn to matchTransform:inverse * hl:matchvec.
    add node(hl:arrivalTime, matchBurn:x, matchBurn:y, matchBurn:z).
    nodeExecute().
    
    print " Tune orbit".
    orbitTunePeriod(dest:obt:period, 10).
}

function travelObtsMatch {
    parameter obt1, obt2.
    local ratio to obt1:period / obt2:period.
    if ratio > (1 - kTravelMatchThreshold)
        and ratio < (1 + kTravelMatchThreshold) {
        return true.
    }
}