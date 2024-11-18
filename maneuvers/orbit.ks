@LAZYGLOBAL OFF.

runOncePath("0:common/control.ks").
runOncePath("0:common/integrate.ks").
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

function orbitCircleAtAp {
    changePeAtAp(ship:obt:apoapsis).
    nodeExecute().
}

function orbitCircleAtPe {
    changeApAtPe(ship:obt:periapsis).
    nodeExecute().
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
    parameter a, rad, e.

    local num to a * (1 - e^2) / rad.
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

    print " Escape with " + vecRound(v_x).
    local soirad to 1e15.
    if body <> sun {    
        set soirad to body:soiradius.
    }

    local startTime to time + delay.
    local r0 to altitude + body:radius.
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
        local aMin to (soirad + r0) / 2.
        // print "a minimum " + aMin.
        local minExit to 1.05 * sqrt(body:mu * (2 / soirad - 1 / aMin)).
        // print "min speed " + minExit.
        local ellipseExit to max(minExit, v_x:mag). 
        set a to 1 / (2 / body:soiradius  - ellipseExit ^ 2 / body:mu).
        // print "a " + a.
        set e to 1 - r0 / a.
        // print "e " + e.
        set spd0 to sqrt(body:mu * (2 / r0 - 1 / a)).
        set deflectAngle to escapeEllipseDeflect(a, soirad, e).
    }
    // print "deflectAngle " + deflectAngle.

    local i_n to shipnorm().
    local i_x to v_x:normalized.
    local ix_dot_in to vDot(i_x, i_n).
    // print "norm dot " + ix_dot_in.
    local spdNorm to spd0 * (ix_dot_in / cos(deflectAngle)).
    // print "spdNorm " + spdNorm.
    if abs(spdNorm) > spd0 {
        print " Could not escape with norm component of " + round(spdNorm).
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

    wait 0.
    add node(startTime + alignDur, 0, spdNorm,
        spdPro - ship:velocity:orbit:mag).
    wait 0.
    return true.
}

function escapeOmni {
    parameter hl.

    print "Escaping " + body:name + " to " + hl:dest:name.
    local canEscapeWith to escapeWith(hl:burnVec, hl:delay).
    if canEscapeWith {
        return.
    }
    print " escape failed, leaving parent orbit".
    local dir to sgn(hl:dest:obt:semimajoraxis - body:obt:semimajoraxis).
    // sqrt(mu / r) is the minimal escape speed
    local escapeSpd to dir * 1.2 * obtMinEscape(body, apoapsis).
    escapePrograde(escapeSpd).
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
        shipStage().
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

function entryPe {
    parameter pe, norm.

    if obt:eccentricity > 1 {
        hyperPe(pe, norm).
    } else {
        ellipseEntryPe(pe, norm).
    }
}

function spdToHyperTurn {
    parameter spd, rpe, rad, mu.

    local a to 1 / (2 / rad - (spd ^ 2) / mu).
    local e to 1 - rpe / a.
    local turn to 2 * arcsin(1 / e).
    return turn.
}

function hyperPe {
    parameter pe, norm.

    local rPe to pe + body:radius.
    local burnTime to time + 2 * 60.
    local shipPos to shipPAt(burnTime).
    local rad to shipPos:mag.
    local startVec to shipVAt(burnTime).
    local currentTurn to spdToHyperTurn(startVec:mag, rPe, rad, body:mu).
    local turn to max(22, currentTurn).

    local e to 1 / sin(turn / 2).
    local a to rPe / (1 - e).
    // print "a " + a.
    // local b to -a / tan(turn / 2).
    // print "b " + b.
    // local realB to -a. //(b - a) / 2.
    // local tanly to -1 * (45 + arcCos(realB / rad)).
    // local tanly to -131.
    local tanly to -1 * arccos((a * (1 - e^2) - rad) / e / rad).
    // print "tanly " + tanly.
    local spd to sqrt(body:mu * (2 / rad - 1 / a)).
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

function ellipseEntryPe {
    parameter pe, norm.

    local burnTime to time + 2 * 60.
    local shipPos to  shipPAt(burnTime).
    local rAp to shipPos:mag.
    local rPe to pe + body:radius.
    local semi to (rAp + rPe) / 2.
    // local ecc to (rAp / rPe) - 1.
    local tgtNorm to vxcl(shipPos, norm):normalized.
    local tgtSpd to sqrt(body:mu * (2 / rAp - 1 / semi)).
    local tgtV to tgtSpd * vCrs(shipPos:normalized, tgtNorm).
    local startV to shipVAt(burnTime).
    local startRnp to obtRnpFromPV(shipPos, startV).
    local burnRnp to startRnp:inverse * (tgtV - startV).
    add node(burnTime, burnRnp:x, burnRnp:y, burnRnp:z).
}

// At Ap, use RCS to tune the period
function orbitTunePeriod {
    parameter tgtPeriod, dur, eps to 0.01.

    local rcsThrust to shipRcsGetThrust().
    local rcsInvThrust to vecInvertComps(rcsThrust).

    enableRcs().
    if vang(facing:forevector, prograde:forevector) < 90 {
        lock steering to lookdirup(prograde:forevector, facing:upvector).
    } else {
        lock steering to lookdirup(retrograde:forevector, facing:upvector).
    }
    set controlThrot to 0.
    wait until vang(facing:forevector, steering:forevector) < 3.
    local startTime to time.
    local stopTime to startTime + dur.
    // use a=(1/(2/r - 1/v^2)) and period to solve for dp / dv
    local dTdv to 3 * obt:period * obt:semimajoraxis / body:mu
        * obt:velocity:orbit:mag.
    local gain to 10 / dTdV.

    until abs(obt:period - tgtPeriod) < eps or time > stopTime {
        local error to tgtPeriod - obt:period.
        local accMag to gain * error.
        local minAcc to .06 * rcsThrust:z / ship:mass.
        set accMag to sgn(accMag) * max(abs(accMag), minAcc).
        local acc to accMag * prograde:forevector.
        shipRcsDoThrust(acc, rcsInvThrust).
        wait 0.
        if abs(accMag) < 1.5 {
            // orbit doesn't update every frame
            set ship:control:translation to zeroV.
            wait 0.1.
        }
    }
    print " orbit error " + (tgtPeriod - obt:period).

    disableRcs().
    unlock steering.
}

function orbitSeparate {
    parameter sepTime, killTime, s to activeShip.
    enableRcs().

    local rcsInvThrust to shipRcsInvThrust().

    controlLock().
    for i in range(sepTime * 10) {
        if i > killTime * 10 {
            set controlSteer to retrograde.
        } else {
            set controlSteer to "KILL".
        }
        local away to -s:position.
        local retro to retrograde:forevector.
        shipRcsDoThrust(0.5 * vxcl(retro, away):normalized, rcsInvThrust).
        wait 0.1.
    }
    controlUnlock().

    disableRcs().
}

function orbitDispose {
    parameter s to activeShip.
    print "Separate".
    sas off.

    orbitSeparate(7, 3, s).
    print "Deorbit burn".

    enableRcs().
    shipActivateAllEngines().
    lock steering to retrograde.
    lock throttle to 0.05.
    wait 3.
    lock throttle to 1.0.
    wait until periapsis < 0.
    lock throttle to 0.
    wait 1.
    print "Finished Deorbit burn".
}

function orbitPatchesInclude {
    parameter startOrbit, bod.
    local orbitIter to startOrbit.
    until false {
        if not orbitIter:hasnextpatch {
            break.
        }
        set orbitIter to orbitIter:nextpatch.
        if orbitIter:body = bod {
            return true.
        }
    }
    return false.
}

function isEscapeVExceeded {
    parameter targetEscapeV, mu, vel, rad, soiradius.

    local semi to obtVisVivaAFromMuVR(mu, vel, rad).
    if semi < 0 {
        local escapeV to obtVisVivaVFromMuRA(mu, soiradius, semi).
        if escapeV > targetEscapeV {
            return true.
        }
    }
    return false.
}

function simulateBurnTillExitV {
    parameter targetEscapeV.
    local pvm to lexicon(
        "p", v(body:position:mag, 0, 0),
        "v", v(0, 0, velocity:orbit:mag),
        "m", mass
    ).
    local burnTime to 0.
    local thrust to ship:maxthrust.
    local flowIsp to shipFlowIsp().
    local drain to flowIsp[0].
    local bodyMu to body:mu.
    local bodySoiRadius to body:soiradius.

    until false {
        set burnTime to burnTime + 1.
        set pvm to proBurnRk4(bodyMu, pvm:p, pvm:v, pvm:m, thrust, drain, 1).
        if isEscapeVExceeded(targetEscapeV, bodyMu, pvm:v:mag, pvm:p:mag,
            bodySoiRadius) {
            break.
        }
    }
    set pvm:t to burnTime.
    return pvm.
}

function orbitSlowEscape {
    parameter escapeV, leaveTime.

    local startPvm to lexicon(
        "p", v(body:position:mag, 0, 0),
        "v", v(0, 0, velocity:orbit:mag),
        "m", mass
    ).
    // local endPvm to proBurnRk4(body:mu, startPvm:p, startPvm:v, startPvm:m,
    //     ship:maxthrust, drain, timeToSpendBudget, 0.5).
    local endPvm to simulateBurnTillExitV(escapeV:mag).

    local bodyBurnAngle to vectorAngleAround(startPvm:p, unitY, endPvm:p).
    // get angle, exit velocity, offset of exit point, time from burn to exit
    local bodyOrbit to createOrbit(endPvm:p, endPvm:v, body, time:seconds).
    local bodyE to bodyOrbit:eccentricity.
    local bodyDeflectAngle to 2 * arcsin(1 / bodyE).
    local bodyPeToApAngle to (90 + bodyDeflectAngle / 2).
    local bodyPostBurnTanly to obtRadiusToTanly(endPvm:p:mag, bodyOrbit).
    local bodyBurnEndToApAngle to bodyPeToApAngle - bodyPostBurnTanly.
    local bodyStartToFinishAngle to bodyBurnAngle + bodyBurnEndToApAngle.

    local bodyBurnStartPos to rotateVecAround(escapeV, unitY,
        -bodyStartToFinishAngle).
    local burnFromPos to (body:position + bodyBurnStartPos).
    local burnFromTanley to posToTanly(burnFromPos, orbit).
    local burnTill to timeBetweenTanlies(orbit:trueanomaly, burnFromTanley,
        orbit).
    
    local period to orbit:period.
    local orbitsTillLeaveDur to
        floor((leaveTime - time:seconds) / period) * period.

    waitWarp(time + orbitsTillLeaveDur + burnTill - 10).
    print " Slow Burn in 10".
    lock steering to prograde.
    wait 10.
    // set controlThrot to 1.
    lock throttle to 1.

    set kuniverse:timewarp:mode to "PHYSICS".
    set kuniverse:timewarp:warp to 4.
    until isEscapeVExceeded(escapeV:mag, body:mu, velocity:orbit:mag,
        body:position:mag, body:soiradius) {
        wait 0.
    }
    kuniverse:timewarp:cancelwarp.
    // set controlThrot to 0.
    lock throttle to 0.
    wait 1.
}