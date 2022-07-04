@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").

global kIntercept to lexicon().
set kIntercept:StartSpan to 2.
set kIntercept:DurSpan to 2.

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
    // print hi.

    return hi.
}

function hlIntercept {
    parameter obtable1, obtable2. 
    parameter offset to v(0, 0, 0).

    local hi to hohmannIntercept(obtable1:orbit, obtable2:orbit).

    local roughT to hi:when + time.
    local roughDur to hi:duration.
    local di to obtable1:obt:period * 0.1.
    local dj to hi:duration * 0.1.

    local rough to lambertGrid(obtable1, obtable2, roughT, roughDur, di, dj).

    local fineT to rough:start.
    local fineDur to rough:duration.
    set di to di / (kIntercept:StartSpan + 1).
    set dj to dj / (kIntercept:DurSpan + 1).

    local fine to lambertGrid(obtable1, obtable2, fineT, fineDur, di, dj).

    return mergeLex(hi, fine).
}

function informedLambert {
    parameter obtable1, obtable2, guessDur.
    
    local dt to .05 * guessDur.
    local startTime to time:seconds + dt * kIntercept:StartSpan + 5 * 60.
    return lambertGrid(obtable1, obtable2, startTime, guessDur, dt, dt).
}

function lambertGrid {
    parameter obtable1, obtable2, guessT, guessDur, di, dj.
    parameter offset to v(0, 0, 0).

    print "LG to " + obtable2 + " in " + (guessDur * sToDays) + " days".

    local best to lexicon().
    set best:totalV to 10 ^ 20.

    for i in range(-kIntercept:StartSpan, kIntercept:StartSpan + 1) {
        for j in range (-kIntercept:DurSpan, kIntercept:DurSpan + 1) {
            local startTime to guessT + i * di.
            local flightDuration to guessDur + j * dj.
            local results to lambertIntercept(obtable1, obtable2, offset,
                startTime, flightDuration).
            if results:ok {
                set results:totalV to results:burnVec:mag. 
                set results:totalV to results:totalV + results:matchVec:mag.
                // print round(results:burnVec:mag) + " -> " + round(results:matchVec:mag).
                if results:totalV < best:totalV {
                    set results:start to startTime.
                    set results:duration to flightDuration.
                    set best to results.
                }
            }
        }
    }

    return best.
}

function courseCorrect {
    parameter dest, duration.
    local dt to .05 * duration.
    local startTime to time:seconds + dt * kIntercept:StartSpan + 5 * 60.
    local correction to lambertGrid(ship, dest, startTime, duration, dt, dt).
    add correction:burnNode.
}