@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/intercept.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:phases/rndv.ks").

global stratIntercept to "INTERCEPT".
global stratSatellite to "SATELLITE_PLANEOF".
global stratEscapeTo to "ESCAPE_TOWARDS".
global stratEscape to "ESCAPE".
global stratOrbiting to "ORBITING".

function travelTo {
    parameter ctx.

    local dest to ctx:dest.

    until false {
        local strat to travelStratTo(dest).
        print strat.

        if strat[0] = stratOrbiting {
            break.
        }
        if strat[0] = stratIntercept {
            travelIntercept(ctx).
            break.
        }
        if strat[0] = stratEscape {
            travelEscape().
        }
        if strat[0] = stratEscapeTo {
            if strat:length = 2{
                travelEscapeTo(ctx, strat[1], strat[1]).
            } else {
                travelEscapeTo(ctx, strat[1], strat[2]).
            }
        }
        if strat[0] = stratSatellite {
            travelSatellite(ctx, strat[1], strat[2]).
        }
    }
}

function travelStratTo {
    parameter targetable.

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
    if targetable:typename <> "BODY" {
        set tgtBodyIter to targetable:obt:body.
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
    // print tgtBodies.
    if ourIdx = 0 {
        if tgtBodies:length = 2 {
            return list(stratIntercept, tgtBodies[0]).
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

    local hl to travelDoubleHl().

    if (target:typename = "BODY") {
        travelIntoSatOrbit(ctx, target, hl:arrivalTime).
        travelCaptureToInc(ctx).
    } else {
        waitWarp(closestApproach(ship, target) - 2 * 60).
        doubleBallisticRcs().
    }
}

function travelEscape {
    escapeWith(body:obt:velocity:orbit:normalized * 100, 0).
    nodeExecute().
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}

function travelEscapeTo {
    parameter ctx, tgtBody, planeOf.

    local hl to hlIntercept(body, tgtBody).
    set hl:dest to tgtBody.
    // it's fine if this is a plane change
    escapeOmni(hl).

    nodeExecute().
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

    local hl to travelDoubleHl().
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
        if orbit:hasnextpatch() and orbit:nextpatch:body = tgtBody {
            break.
        }
        print " Refining Intercept " + i.
        local arrivalEta to arrivalTime - time.
        local cc to courseCorrect(tgtBody, arrivalEta).
        set arrivalEta to cc:arrivalTime.
        nodeExecute().
    }

    print " Waiting in travelIntoSatOrbit".
    waitWarp(time:seconds + orbit:nextpatcheta + 60).
}

function travelCaptureToInc {
    parameter ctx.
    print "Capture into orbit around " + body:name.

    if not ctx:haskey("altitude") {
        print " Using default altitude".
        set ctx:altitude to kWarpHeights[body].
    }
    if not ctx:haskey("inclination") {
        print " Using default inclination".
        set ctx:inclination to 0.
    }
    local norm to inclinationToNorm(ctx:inclination).
    hyperPe(ctx:altitude + 500, norm).
    nodeExecute().
    if periapsis < ctx:altitude {
        hyperPe(ctx:altitude + 500, norm).
        nodeExecute().
    }
    circleNextExec(ctx:altitude).
}

function travelCaptureToPlaneOf {
    parameter ctx, tgt.

    // TODO efficient plane change.
    local pe to tgt:obt:periapsis * 1.5.
    local norm to normOf(tgt:obt).
    hyperPe(pe, norm).
    nodeExecute().
    circleNextExec(pe).

}

function travelDoubleHl {
    // The function may return a plane change instead.

    local hl to hlIntercept(ship, target).
    add hl:burnNode.
    nodeExecute().

    if hl:haskey("planes") and hl:planes {
        print " Retrying HL intercept after plane change".
        set hl to hlIntercept(ship, target).
        add hl:burnNode.
        nodeExecute().
    }

    return hl.
}