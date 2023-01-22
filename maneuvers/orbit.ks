@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").

// Match planes at closest node preserving radius.
// Works by applying a pro/norm burn based on angle difference.
function matchPlanesNode {
    parameter targetNorm.
    // print "Target Norm " + targetNorm.
    local norm to shipNorm().
    local asc to vCrs(targetNorm, norm):normalized.

    local shipPos to shipPAt(time).
    local pToAscAngle to vectorAngleAround(shipPos, norm, asc).
    // take sooner one
    local pToNAscAngle to vectorAngleAround(shipPos, norm, -asc).
    if pToAscAngle > pToNAscAngle {
        set asc to -1 * asc.
        set pToAscAngle to pToNAscAngle.
    }
    // print "tanly " + obt:trueanomaly.
    // print "tanlyA " + (obt:trueanomaly + pToAscAngle).

    local delayToNode to timeBetweenTanlies(obt:trueanomaly, 
        obt:trueanomaly + pToAscAngle, obt).
    local burnTime to time + delayToNode.
    local burnStartSpd to velocityAt(ship, burnTime):orbit:mag.
    local dt to vectorAngleAround(norm, asc, targetNorm).

    local dv to 2 * burnStartSpd * sin(dt / 2).
    local nd to node(burnTime, 0, dv * cos(dt / 2), -dv * sin(dt / 2)).  
    return nd.
}

function matchPlanes {
    parameter targetNorm.
    add matchPlanesNode(targetNorm).
}

// Match planes at closest node, killing radial v and setting opposite alt.
// Works differently enough from matchPlanes that I will keep both.
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

function escapeHyperDeflect {
    parameter e.
    return arcsin(1 / e).
}

function escapeEllipseDeflect {
    parameter a, r, e.

    local num to a * (1 - e^2) / r.
    // print "num " + num.
    local cosTanly to (num - 1) / e.
    // print "cosTanly " + cosTanly.
    local tanly to arcCos(cosTanly).
    local flightPath to arctan(e * sin(tanly) / (1 + e * cos(tanly))).
    // print "flightPath " + flightPath.
    return tanly - flightPath.
} 

function escapePrograde {
    parameter spd, rad to 0.
    
    local bestPro to vxcl(shipNorm(), body:obt:velocity:orbit):normalized.
    local escapeV to bestPro * spd + body:obt:position:normalized * rad. 
    escapeWith(escapeV, 0).
}

function escapeWith {
    // v_x is the excess velocity in the parent orbit
    parameter v_x, delay.

    if body = sun { return. }

    local startTime to time + delay.
    local r0 to altitude + body:radius.
    local soirad to body:soiradius.
    local escapeRIntegral to 1 / r0 - 1 / soirad.
    // print "escape integral " + (escapeRIntegral * r0).

    local spd0 to sqrt(v_x:mag ^ 2 + 2 * body:mu * escapeRIntegral).
    // print "v0 " + spd0.
    local a to 1 / (2 / r0 - spd0 ^ 2 / body:mu).
    // print "a " + a.
    // print "a / soi " + (a / body:soiradius).
    local e to 1 - r0 / a.
    // print "e " + e.
    local deflectAngle to 0.
    if (e > 1) {
        set deflectAngle to escapeHyperDeflect(e).
    } else {
        local aMin to (body:soiradius + r0) / 2.
        // print "a minimum " + aMin.
        local minExit to 1.05 * sqrt(body:mu * (2 / soirad - 1 / aMin)).
        // print "min speed " + minExit.
        local ellipseExit to max(minExit, v_x:mag). 
        set a to 1 / (2 / body:soiradius  - ellipseExit ^ 2 / body:mu).
        // print "a " + a.
        set e to 1 - r0 / a.
        // print "e " + e.
        set spd0 to sqrt(body:mu * (2 / r0 - 1 / a)).
        set deflectAngle to escapeEllipseDeflect(a, body:soiradius, e).
    }
    // print "deflectAngle " + deflectAngle.

    local i_n to shipnorm().
    local i_x to v_x:normalized.
    local ix_dot_in to vDot(i_x, i_n).
    // print "norm dot " + ix_dot_in.
    local spdNorm to spd0 * (ix_dot_in / cos(deflectAngle)).
    // print "spdNorm " + spdNorm.
    if abs(spdNorm) > spd0 {
        return false.
    }
    local spdPro to sqrt(spd0 ^ 2 - spdNorm ^ 2).
    // print "spdPro " + spdPro.

    local cosDeflect to cos(deflectAngle).
    local sinDeflect to sin(deflectAngle).
    local i_rx to vCrs(i_n, i_x):normalized.
    local i0 to i_x * cosDeflect + i_rx * sinDeflect.
    // local cosTheta to spdPro / spd0.
    // local i0 to removeComp(v_x, i_n) * cosTheta * cosDeflect + i_rx * sinDeflect.
    local i0_p to vCrs(i_n, i0):normalized.

    local pos0 to i0_p + body:position. 
    local burnTanly to posToTanly(pos0, obt).
    // print "burnTanly " + burnTanly.
    local shipPos to positionAt(ship, startTime).
    local startTanly to posToTanly(shipPos, obt).
    // print "start tanly " + startTanly.
    local alignDur to timeBetweenTanlies(startTanly, burnTanly, obt).
    // print "alignDur " + round(alignDur / 60) + " min".

    add node(startTime + alignDur, 0, spdNorm,
        spdPro - ship:velocity:orbit:mag).
    return true.
}

function escapeOmni {
    parameter hl.

    print "Escaping " + body:name + " to " + hl:dest:name.
    local incNodeP to vcrs(normOf(hl:dest:obt), normOf(body:obt)):normalized.
    local bodyP to positionAt(body, hl:start) - body:obt:body:position.
    // clearVecDraws().
    // vecdraw(kerbin:position, bodyP, red, "body", 1, true).
    // vecdraw(kerbin:position, incNodeP * mun:altitude, blue, "an", 1, true).
    // vecdraw(kerbin:position, normOf(body:obt) * mun:altitude, green, "mun", 1, true).
    // vecdraw(kerbin:position, normOf(minmus:obt) * mun:altitude, yellow, "min", 1, true).
    local kNodeAllow to 10.
    local nodeAng to vang(bodyP, incNodeP).
    print " AN is " + round(nodeAng) + " away, want 0 or 180".
    if nodeAng < kNodeAllow or nodeAng > (180 - kNodeAllow) {
        print " Attempting single burn transfer".
        local canEscapeWith to escapeWith(hl:burnVec, hl:when).
        if canEscapeWith {
            return.
        }
    }

    local hi to hohmannIntercept(body:obt, hl:dest:obt).
    local bv to velocityAt(body, hi:start):orbit.
    local normVsPro to vang(shipNorm(), bv).
    print " Considering a hohmann escape, normVsPro " + round(normVsPro) + ", want 90".
    if abs(normVsPro - 90) < kNodeAllow {
        print " Doing hohmann".
        escapeWith(hi:vd * bv:normalized, hi:when).
    } else {
        print " Just getting out".
        local escapeSpd to 40 * sgn(hi:vd).
        escapePrograde(escapeSpd).
    }
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
    // print "a " + a.
    // local b to -a / tan(turn / 2).
    // print "b " + b.
    // local realB to -a. //(b - a) / 2.
    // local tanly to -1 * (45 + arcCos(realB / r)).
    // local tanly to -131.
    local tanly to -1 * arccos((a * (1 - e^2) - r) / e / r).
    // print "tanly " + tanly.
    local spd to sqrt(body:mu * (2 / r - 1 / a)).
    // print "spd " + spd.
    local flightA to arcTan2(e * sin(tanly), 1 + e * cos(tanly)).
    // print "flightA " + flightA.

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

// At Ap, use RCS to tune the period
function orbitTunePeriod {
    parameter tgtPeriod, dur, eps to 0.01.

    controlLock().
    set controlSteer to prograde.
    set controlThrot to 0.
    wait until vang(facing:forevector, prograde:forevector) < 3.
    local startTime to time.
    local stopTime to startTime + dur.
    local gain to -0.1.
    enableRcs().

    until abs(obt:period - tgtPeriod) < eps or time > stopTime {
        local error to obt:period - tgtPeriod.
        local output to v(0, 0, gain * error).
        local clampedOut to vecMinMag(output, 0.06).
        set ship:control:translation to clampedOut.
        wait 0.
    }

    disableRcs().
    controlUnlock().
}