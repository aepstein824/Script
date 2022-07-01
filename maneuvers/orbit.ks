@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").

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
    parameter exitSpd, delay.
    if body = sun { return. }

    local escapeSign to 1.
    if exitSpd < 0 {
        set escapeSign to -1.
        set exitSpd to -exitSpd.
    }
    // set delay to 0.

    local startTime to time + delay.
    local r0 to altitude + body:radius.
    local escapeRIntegral to 1 / r0 - 1 / body:soiradius.
    // print "escape integral " + escapeRIntegral.
    local v0 to sqrt(exitSpd^2 + 2 * body:mu * escapeRIntegral).
    // print "sqrt(" + exitSpd ^2 + " + " + (2 * body:mu / r0) + ")".
    // print "v0 " + v0.

    local a to 1 / (2 / r0 - v0 ^ 2 / body:mu).
    local e to max(1 - r0 / a, 1).
    // print "e " + e.
    local deflectAngle to arcsin(1 / e).
    // print "deflectAngle " + deflectAngle.
    // velocity is 90 offset from position.
    local burnToInfAngle to deflectAngle + 90.
    // print "Just Checking " + arccos(-1/e).

    local bodyV to velocityAt(body, startTime):orbit.
    local bodyVAsPos to escapeSign * bodyV + body:position.
    print "Escape " + escapeSign.
    local infTanly to posToTanly(bodyVAsPos, obt).
    print "inf tanly " + infTanly.
    local startTanly to posToTanly(shipPAt(startTime), obt).
    print "start tanly " + startTanly.
    local burnTanly to posmod(infTanly - burnToInfAngle, 360).
    print "burn tanly " + burnTanly.
    local alignDur to timeBetweenTanlies(startTanly, burnTanly, obt).
    print "alignDur " + alignDur.

    add node(startTime + alignDur, 0, 0, v0 - ship:velocity:orbit:mag).
}