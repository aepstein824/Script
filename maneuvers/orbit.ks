@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/node.ks").

function matchPlanes {
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
    local fudge to .965.
    local escapeSpd to fudge * sqrt(2 * body:mu / burnR).
    local ds to escapeSpd - shipVAt(burnTime):mag.

    add node(burnTime, 0, 0, ds).
}

function matchPlanesAndSemi {
    parameter targetNorm, targetOp.
    local shipPePos to positionAt(ship, time + obt:eta:periapsis) - body:position.
    local norm to shipNorm().
    local crs to vCrs(targetNorm, norm):normalized.

    local delayFromPe to timeBetweenTanlies(0, 
        vectorAngleAround(shipPePos, norm, crs), obt).
    local burnTime to time + obt:eta:periapsis + delayFromPe.

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
        changeApAtPe(height).
        nodeExecute().
    } else {
        changeApAtPe(height).
        nodeExecute().
        changePeAtAp(height).
        nodeExecute().
    }
}
