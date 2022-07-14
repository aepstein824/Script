@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").

// circleNextExec(95000).

function matchPlanes {
    // combine with matchplanesandsemi
    parameter targetNorm.
    local shipPePos to positionAt(ship, time + obt:eta:periapsis) - body:position.
    local norm to shipNorm().
    local crs to vCrs(targetNorm, norm):normalized.

    print "tanly = " + vectorAngleAround(shipPePos, norm, crs). 
    local delayFromPe to timeBetweenTanlies(0, 
        vectorAngleAround(shipPePos, norm, crs), obt).
    local burnTime to time + obt:eta:periapsis + delayFromPe.
    local burnStartSpd to velocityAt(ship, burnTime):orbit:mag.
    local dt to vang(norm, targetNorm).

    local dv to 2 * burnStartSpd * sin(dt / 2).
    add node(burnTime, 0, dv * cos(dt / 2), -dv * sin(dt / 2)).  
}

function escapeRetro {
    // probably only works from circle
    local burnDir to body:position - body:obt:body:position.
    local norm to shipNorm().
    local pePos to shipPAtPe().
    local burnTanly to vectorAngleAround(pePos, norm, burnDir).

    local burnTime to timeBetweenTanlies(obt:trueanomaly, burnTanly, obt) + time.
    local burnPos to shipPAt(burnTime). 
    local burnR to burnPos:mag.
    local fudge to .9.
    local escapeSpd to fudge * sqrt(2 * body:mu / burnR).
    local ds to escapeSpd - shipVAt(burnTime):mag.

    local nd to node(burnTime, 0, 0, ds).
    add nd.
    until nd:obt:hasnextpatch() {
        set nd:prograde to nd:prograde + 1.
    }
}

function matchPlanesAndSemi {
    parameter targetNorm, targetOp.
    local norm to shipNorm().
    local crs to vCrs(targetNorm, norm):normalized.
    // take sooner one
    if vdot(ship:prograde:vector, crs) < 0 {
        set crs to -1 * crs.
    }

    local shipPePos to positionAt(ship, time + obt:eta:periapsis) - body:position.
    local delayFromPe to timeBetweenTanlies(0, 
        vectorAngleAround(shipPePos, norm, crs), obt).
    local burnTime to time + obt:eta:periapsis + delayFromPe.
    if burnTime - time > obt:period {
        set burnTime to burnTime - obt:period.
    }

    local burnStart to velocityAt(ship, burnTime):orbit.
    local burnPos to positionAt(ship, burnTime) - body:position.
    local semi to (burnPos:mag + body:radius + targetOp) / 2.
    local matchMag to sqrt(body:mu * (2 / burnPos:mag - 1 / semi)).
    local matchPro to vCrs(burnPos, targetNorm):normalized.
    local matchV to matchMag * matchPro.

    local burnPro to burnStart:normalized.
    local burnRad to vCrs(norm, burnPro):normalized.
    local dv to matchV - burnStart.
    add node(burnTime, vDot(dv, burnRad), vDot(dv, norm), vDot(dv, burnPro)).
}

function changePeAtAp {
    parameter destPe.
    local ra to ship:obt:apoapsis + ship:body:radius.
    local rp to ship:obt:periapsis + ship:body:radius.
    local rd to destPe + ship:body:radius.
    local va to sqrt(2 * ship:body:mu * rp / ra / (ra + rp)).
    local vd to sqrt(2 * ship:body:mu * rd / ra / (ra + rd)).
    add node(ship:obt:eta:apoapsis + time, 0, 0, vd - va).
}

function changeApAtPe {
    parameter destAp.
    local ra to ship:obt:apoapsis + ship:body:radius.
    local rp to ship:obt:periapsis + ship:body:radius.
    local rd to destAp + ship:body:radius.
    local va to sqrt(2 * ship:body:mu * ra / rp / (ra + rp)).
    local vd to sqrt(2 * ship:body:mu * rd / rp / (rp + rd)).
    add node(ship:obt:eta:periapsis + time, 0, 0, vd - va).
}

function circleNextExec {
    parameter height.

    if obt:eta:apoapsis < obt:eta:periapsis {
        changePeAtAp(height).
        nodeExecute().
    } else {
        changeApAtPe(height).
        nodeExecute().
    }

    // detect cross over
    if abs(obt:apoapsis - height) > abs(obt:periapsis - height) {
        changeApAtPe(height).
        nodeExecute().
    } else {
        changePeAtAp(height).
        nodeExecute().
    }
}

function dontEscape {
    print obt:nextpatch():transition + " " + obt:nextpatch:apoapsis.
    if obt:nextpatch():transition <> "FINAL" {
            print "ESCAPING?!".
            add node(time + 60, 0, 0, -50).
            wait 0.
            nodeExecute().
    } else {
        print "Just fine actually " + obt:nextpatch():transition <> "FINAL".
    }
}

function escapeWith {
    parameter v_x, delay.

    if body = sun { return. }

    // set delay to 0.

    local startTime to time + delay.
    local r0 to altitude + body:radius.
    local escapeRIntegral to 1 / r0 - 1 / body:soiradius.
    // print "escape integral " + escapeRIntegral.
    
    // local bodyV to velocityAt(body, startTime):orbit.
    // add body position to get to ship coordinates
    // local bodyVAsPos to bodyV + body:position.
    // print "Escape " + escapeSign.

    // local bodyP to positionAt(body, startTime)
        // - positionAt(body:obt:body, startTime).
    // local normClosest to removeComp(norm, bodyP).


    // local incEx to vectorAngleAround(bodyV, bodyP, vEx).
    // print "incEx " + incEx.

    local spd0 to sqrt(v_x:mag ^ 2 + 2 * body:mu * escapeRIntegral).
    print "v0 " + spd0.
    local a to 1 / (2 / r0 - spd0 ^ 2 / body:mu).
    local e to max(1 - r0 / a, 1).
    // print "e " + e.
    local deflectAngle to arcsin(1 / e).
    print "deflectAngle " + deflectAngle.

    local i_n to shipnorm().
    local i_x to v_x:normalized.
    local ix_dot_in to vDot(i_x, i_n).
    local spdNorm to spd0 * (ix_dot_in / cos(deflectAngle)).
    local spdPro to sqrt(spd0 ^ 2 - spdNorm ^ 2).

    print "spdNorm " + spdNorm.
    print "spdPro " + spdPro.

    local cosDeflect to cos(deflectAngle).
    local sinDeflect to sin(deflectAngle).
    local i_rx to vCrs(i_n, i_x):normalized.
    local i0 to i_x * cosDeflect + i_rx * sinDeflect.
    // local cosTheta to spdPro / spd0.
    // local i0 to removeComp(v_x, i_n) * cosTheta * cosDeflect + i_rx * sinDeflect.
    local i0_p to vCrs(i_n, i0):normalized.

    local pos0 to i0_p + body:position. 
    local burnTanly to posToTanly(pos0, obt).
    print "burnTanly " + burnTanly.
    local shipPos to positionAt(ship, startTime).
    local startTanly to posToTanly(shipPos, obt).
    print "start tanly " + startTanly.
    local alignDur to timeBetweenTanlies(startTanly, burnTanly, obt).
    print "alignDur " + round(alignDur / 60) + " min".

    add node(startTime + alignDur, 0, spdNorm,
        spdPro - ship:velocity:orbit:mag).
    wait 10000.
}

function refinePe {
    parameter low, high.
    add node(time, 1, 0, 1).
    local proAndOut to nextnode:deltav:normalized.
    if ship:periapsis < low {
        lock steering to proAndOut.
    } else if ship:periapsis > high {
        lock steering to -1 * proAndOut.
    } 
    wait 10.
    until ship:periapsis > low and ship:periapsis < high {
        lock throttle to 0.1.
        nodeStage().
        wait 0.
    }
    lock throttle to 0.
    remove nextNode.
    wait 1.
    return.
}

function inclinationToNorm {
    parameter inc.

    local poleBodyPos to latlng(90, 0):position - body:position. 
    local shipPos to shipPAt(time).
    local equatorPos to vCrs(shipPos, poleBodyPos). 
    local norm to cos(inc) * poleBodyPos:normalized
        - sin(inc) * equatorPos:normalized.
    return norm.
}

function spdToHyperTurn {
    parameter spd, rpe, r, mu.

    local a to 1 / (2 / r - (spd ^ 2) / mu).
    local e to 1 - rpe / a.
    local turn to 2 * arcsin(1 / e).
    return turn.
}

function hyperPe {
    parameter pe, norm.

    local burnTime to time + 2 * 60.
    local rPe to pe + body:radius.
    local shipPos to shipPAt(burnTime).
    local r to shipPos:mag.
    local startVec to shipVAt(burnTime).
    local currentTurn to spdToHyperTurn(startVec:mag, rPe, r, body:mu).
    local turn to max(22, currentTurn).

    local e to 1 / sin(turn / 2).
    local a to rPe / (1 - e).
    print "a " + a.
    // local b to -a / tan(turn / 2).
    // print "b " + b.
    // local realB to -a. //(b - a) / 2.
    // local tanly to -1 * (45 + arcCos(realB / r)).
    // local tanly to -131.
    local tanly to -1 * arccos((a * (1 - e^2) - r) / e / r).
    print "tanly " + tanly.
    local spd to sqrt(body:mu * (2 / r - 1 / a)).
    print "spd " + spd.
    local flightA to arcTan2(e * sin(tanly), 1 + e * cos(tanly)).
    print "flightA " + flightA.

    local around to vCrs(shipPos, norm):normalized.
    local out to shipPos:normalized.
    local hyperV to spd * (around * cos(flightA) + out * sin(flightA)).

    local startPro to startVec:normalized.
    local startRad to removeComp(shipPos, startPro):normalized.
    local startNorm to vCrs(startPro, startRad).

    local burnVec to hyperV - startVec.
    local burnRad to vDot(burnVec, startRad).
    local burnNorm to vDot(burnVec, startNorm).
    local burnPro to vDot(burnVec, startPro).
    add node(burnTime, burnRad, burnNorm, burnPro).
}
