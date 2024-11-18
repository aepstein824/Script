@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").

global kIntercept to lexicon().
set kIntercept:StartSpan to 4.
set kIntercept:DurSpan to 4.

function hohmannTransfer {
    parameter rd, ra, mu.
    local a to (rd + ra) / 2.

    local rl to min(rd, ra).
    local rh to max(rd, ra).
    local vl to sqrt(mu / rl) * (sqrt(rh / a) - 1).
    local vh to sqrt(mu / rh) * (1- sqrt(rl / a)).

    local ht to lexicon().
    set ht:duration to constant:pi * sqrt(a ^ 3 / mu).
    set ht:dv to vl + vh.
    if ra > rd {
        set ht:vd to vl.
        set ht:va to vh.
    } else {
        set ht:vd to -vh.
        set ht:va to -vl.
    }
    return ht.
}

function hohmannIntercept {
    parameter obt1, obt2.

    local mu to obt1:body:mu.
    local rd to obt1:semimajoraxis.
    local ra to obt2:semimajoraxis.
    local mm2 to 0.
    if ra < 0 {
        // hyperbolic, just use periapsis
        set ra to obt2:periapsis.
        local spd2 to obt2:velocity:orbit:mag.
        set mm2 to 360 * spd2 / (constant:pi * ra).
    } else {
        set mm2 to 360 / obt2:period.
    }

    local hi to hohmannTransfer(rd, ra, mu).

    local mm1 to 360 / obt1:period.
    set hi:transAngle to 180 - mm2 * hi:duration.
    local rel0 to posToTanly(obt2:position, obt1) - obt1:trueanomaly.
    // assume same direction
    // mmRel is the motion of 2 with respect to 1, eg Mun going backwards
    // relative to a ship in LKO.
    local mmRel to mm2 - mm1.
    // print "MM2 = " + mm2.
    // print "MM1 = " + mm1.
    // print "Rel0 = " + rel0.

    local t to (hi:transAngle - rel0) / mmRel.
    local period to 360 / abs(mmRel).
    set hi:relPeriod to period.
    print " Rel period around " + obt1:body:name + " = " + timeRoundStr(period).
    if t < 0 {
        set t to posmod(t, period).
    }
    set hi:delay to t.
    set hi:start to t + time:seconds.
    set hi:arrivalTime to time:seconds + hi:delay + hi:duration.
    set hi:burnNode to node(hi:start, 0, 0, hi:vd).

    return hi.
}

function hlIntercept {
    parameter obtable1, obtable2, options to lexicon().

    set options to options:copy().
    local obtLead to keyOrDefault(options, "obtLead", 0).
    local obtLeadDelay to -obtLead * 360 / obtMeanMotionRelative(obtable1:obt,
        obtable2:obt).

    local hi to hohmannIntercept(obtable1:orbit, obtable2:orbit).
    local q1isBody to obtable1:typename = "Body".
    local q2isBody to obtable2:typename = "Body".
    set hi:start to hi:start + obtLeadDelay.

    set hi:dest to obtable2.
    local roughT to hi:start.
    local roughDur to hi:duration.
    local di to hi:relPeriod * 0.1.
    local dj to hi:duration * 0.1.

    local qBothCircles to true.

    local kPlaneAllow to 2.
    local obt1 to obtable1:obt.
    local obt2 to obtable2:obt.
    local norm1 to normOf(obt1).
    local norm2 to normOf(obt2).
    local inclination to vang(norm1, norm2).
    local qInclination to inclination > kPlaneAllow.

    local bodyP to positionAt(obtable1, hi:start) - obt1:body:position.
    local hiOnPlane2 to abs(vang(norm2, bodyP) - 90).
    local qHiOnPlane2 to hiOnPlane2 < kPlaneAllow.

    print " Criteria:".
    print "  Inclination   : " + qInclination + " " + round(inclination, 2).
    if qInclination {
        print "  Both circles  : " + qBothCircles.
        if qBothCircles {
            print "  Hi on plane 2 : " + qHiOnPlane2
                + " " + round(hiOnPlane2, 2).
        }
    }

    if qInclination and qBothCircles and not qHiOnPlane2 {
        print "  1 is body     : " + q1isBody.
        if q1isBody {
            print " Will ignore planes".
            set options:ignorePlane to true.
        } else if q2isBody {
            print "  2 is body     : " + q2isBody.
            print " Changing planes first".
            local nd to matchPlanesNode(norm2).
            set hi:burnNode to nd.
            set hi:planes to true.
            return hi.
        }
    }

    local lamb to doubleLambert(obtable1, obtable2, roughT, roughDur, di, dj,
        options).

    local merged to mergeLex(hi, lamb).

    // clearVecDraws().
    // local bodyPos to obtable1:obt:body:position.
    // vecdraw(bodyPos, positionAt(obtable1, merged:start) - bodyPos,
        // rgb(0, 0, 1), "p1", 1.0, true).
    // vecdraw(bodyPos, positionAt(obtable2, merged:arrivalTime) - bodyPos,
        // rgb(0, 1, 0), "p2", 1.0, true).

    return merged.
}

function doubleLambert {
    parameter obtable1, obtable2, guessT, guessDur, di, dj.
    parameter options to lexicon().

    local roughT to guessT.
    local roughDur to guessDur.

    local rough to lambertGrid(obtable1, obtable2, roughT, roughDur, di, dj,
        options).

    local fineT to rough:start.
    local fineDur to rough:duration.
    set di to di / (kIntercept:StartSpan + 1) / 2.
    set dj to dj / (kIntercept:DurSpan + 1) / 2.

    local fine to lambertGrid(obtable1, obtable2, fineT, fineDur, di, dj,
        options).
    return fine.
}

function lambertGrid {
    parameter obtable1, obtable2, guessT, guessDur, di, dj.
    parameter options to lexicon().

    print (" LGrid to " + obtable2:name + " in "
        + timeRoundStr(detimestamp(guessT - time)) + ", " 
        + timeRoundStr(detimestamp(guessDur)) + " long "
        + options:keys:join(" ")).

    local best to lexicon().
    set best:totalV to 10 ^ 20.
    
    local extra to choose 2 if (obtable1:obt:body = sun) else 1.
    local lowI to -kIntercept:StartSpan * extra.
    local highI to kIntercept:StartSpan * extra + 1.
    local lowJ to -kIntercept:DurSpan * extra.
    local highJ to kIntercept:DurSpan * extra + 1.

    until guessT + di * lowI > time {
        set guessT to guessT + di.
    }
    until guessDur + dj * lowJ > 1 {
        set guessDur to guessDur + dj.
    }

    for i in range(lowI, highI) {
        for j in range (lowJ, highJ) {
            local startTime to guessT + i * di.
            local flightDuration to guessDur + j * dj.
            // print "Duration " + round(flightDuration * sToHours, 2).
            local results to lambertIntercept(obtable1, obtable2, startTime,
                flightDuration, options).
            if results:ok {
                set results:totalV to results:burnVec:mag
                    + 0.8 * results:matchVec:mag.
                // print "(" + i + ", " + j + ") "
                //     + round(results:burnVec:mag) + " -> "
                //     + round(results:matchVec:mag).
                if results:totalV < best:totalV {
                    set results:start to startTime.
                    set results:delay to startTime - time:seconds.
                    set results:duration to flightDuration.
                    set results:arrivalTime to startTime + flightDuration.
                    set best to results.
                }
            }
        }
    }

    return best.
}

function courseCorrect {
    parameter dest, duration, options to lexicon().

    local dt to duration * .1.
    local startTime to time + dt * kIntercept:StartSpan + 5 * 60.
    local correction to doubleLambert(ship, dest, startTime, duration, dt, dt,
        options).
    add correction:burnNode.
    return correction.
}