@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").

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
        // hyperbolic, just use periapse
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
    local mmRel to mm2 - mm1.
    // print "Rel Mean Motion = " + mmRel.
    // print "MM2 = " + mm2.
    // print "MM1 = " + mm1.
    // print "Rel0 = " + rel0.

    local t to (hi:transAngle - rel0) / mmRel.
    if t < 0 {
        local period to 360 / abs(mmRel).
        set t to posmod(t, period).
    }
    set hi:when to t.
    set hi:start to t + time.
    set hi:arrivalTime to time + hi:when + hi:duration.
    set hi:burnNode to node(hi:start, 0, 0, hi:vd).
    // print hi.

    return hi.
}

function hlIntercept {
    parameter obtable1, obtable2. 

    local hi to hohmannIntercept(obtable1:orbit, obtable2:orbit).
    local deviations to obtable2:typename = "Body".
    
    if obtable1:obt:eccentricity < 0.2 and obtable1:obt:eccentricity < 0.2 { 
        local norm1 to normOf(obtable1:obt).
        local norm2 to normOf(obtable2:obt).

        local incNodeP to vcrs(norm1, norm2):normalized.
        local bodyP to positionAt(obtable1, hi:start) - obtable1:obt:body:position.

        local kNodeAllow to 3.
        local nodeAng to vang(bodyP, incNodeP).
        if vang(norm1, norm2) > 2 {
            if deviations and nodeAng > kNodeAllow
                and nodeAng < (180 - kNodeAllow) {
                print " Changing planes first".
                local nd to matchPlanesNode(norm2).
                set hi:burnNode to nd.
                set hi:planes to true.
                return hi.
            } else {
                print " AN is " + round(nodeAng) + " away, want 0 or 180".
            }
        }
    }

    set hi:dest to obtable2.
    local roughT to hi:start.
    local roughDur to hi:duration.
    local di to obtable1:obt:period * 0.1.
    local dj to hi:duration * 0.1.

    local fine to doubleLambert(obtable1, obtable2, roughT, roughDur, di, dj).

    local merged to mergeLex(hi, fine).

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

    local roughT to guessT.
    local roughDur to guessDur.

    local rough to lambertGrid(obtable1, obtable2, roughT, roughDur, di, dj).

    local fineT to rough:start.
    local fineDur to rough:duration.
    set di to di / (kIntercept:StartSpan + 1) / 2.
    set dj to dj / (kIntercept:DurSpan + 1) / 2.

    local fine to lambertGrid(obtable1, obtable2, fineT, fineDur, di, dj).
    return fine.
}

function lambertGrid {
    parameter obtable1, obtable2, guessT, guessDur, di, dj.

    print (" LGrid to " + obtable2:name + " in "
        + round((guessT - time):seconds * sToDays) + "d, " 
        + round(detimestamp(guessDur) * sToDays) + "d long").

    local best to lexicon().
    set best:totalV to 10 ^ 20.
    
    local extra to choose 2 if (obtable1:obt:body = sun) else 1.
    local lowI to -kIntercept:StartSpan * extra.
    local highI to kIntercept:StartSpan * extra + 1.
    local lowJ to -kIntercept:DurSpan * extra.
    local highJ to kIntercept:DurSpan * extra + 1.

    until guessT + di * lowI > time {
        print " advancing guess time".
        set guessT to guessT + di.
    }
    until guessDur + dj * lowJ > 1 {
        print " advancing guess dur".
        set guessDur to guessDur + dj.
    }

    for i in range(lowI, highI) {
        for j in range (lowJ, highJ) {
            local startTime to guessT + i * di.
            local flightDuration to guessDur + j * dj.
            // print "Duration " + round(flightDuration * sToHours, 2).
            local results to lambertIntercept(obtable1, obtable2, startTime,
                flightDuration).
            if results:ok {
                set results:totalV to results:burnVec:mag. 
                set results:totalV to results:totalV + results:matchVec:mag.
                // print "(" + i + ", " + j + ") "
                //     + round(results:burnVec:mag) + " -> "
                //     + round(results:matchVec:mag).
                if results:totalV < best:totalV {
                    set results:start to startTime.
                    set results:when to startTime - time.
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
    parameter dest, duration.

    local dt to .1 * duration.
    local startTime to time + dt * kIntercept:StartSpan + 5 * 60.
    local correction to doubleLambert(ship, dest, startTime, duration, dt, dt).
    add correction:burnNode.
    return correction.
}