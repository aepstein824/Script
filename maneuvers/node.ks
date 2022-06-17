@LAZYGLOBAL OFF.

declare global kNode to lexicon().

function nodeExecute {
    local nd to nextnode.
    print "Node in: " + round(nd:eta) 
        + ", DeltaV: " + round(nd:deltav:mag).
    local dv to nd:deltav:mag.


    local flowIsp to getFlowIsp().
    local flow to flowIsp[0].
    local ve to flowIsp[1] * 9.81.
    local burnRatio to constant:e ^ (-1 * dv / ve).
    local rocketEstimate to (1 - burnRatio)  * ship:mass / flow.

    local warpTime to nd:eta - rocketEstimate / 2 - 60.
    waitWarp(time:seconds + warpTime).
    local done to false.
    local nodeDv0 to nd:deltav.
    lock steering to nd:deltav.
    until vang(nodeDv0, ship:facing:vector) < 3 { wait 0. }
    set kuniverse:timewarp:rate to 5.
    wait until nd:eta <= rocketEstimate / 2 + 1.
    kuniverse:timewarp:cancelwarp().
    wait until nd:eta <= rocketEstimate / 2.

    until done {
        local maxAcceleration to ship:maxthrust/ship:mass.
        if maxAcceleration > 0 {
            lock throttle to min(nd:deltav:mag / maxAcceleration, 1).
        }

        if nd:deltav:mag < 0.3 or vdot(nodeDv0, nd:deltav) < 0  {
            set done to true.
        }

        nodeStage().
        wait 0.
    }

    unlock steering.
    unlock throttle.
    wait 0.
    remove nd.
}

function nodeStage {
    declare local shouldStage to maxThrust = 0 and stage:ready
        and stage:number > 0.

    if shouldStage {
        print "Staging " + stage:number.
        stage.
    }
}
        
function getFlowIsp {
    local totalFuelFlow to 0.
    local totalIsp to 0.
    local engineList to List().
    list engines in engineList.
    for engine in engineList {
        if engine:ignition {
            local massFlow to 0.
            for r in engine:consumedResources:values {
                set massFlow to massFlow 
                    + r:maxfuelflow * r:density.
            }
            set totalFuelFlow to totalFuelFlow + massFlow.
            set totalIsp to totalIsp + engine:isp * massFlow.
        }
    }
    return List(totalFuelFlow, totalIsp / totalFuelFlow).
}

function waitWarp {
    parameter endTime.
    kuniverse:timewarp:warpto(endTime).
    wait until time:seconds > endTime.
    wait until ship:unpacked.
}

function changePe {
    parameter destPe.
    local ra to ship:obt:apoapsis + ship:body:radius.
    local rp to ship:obt:periapsis + ship:body:radius.
    local rd to destPe + ship:body:radius.
    local va to sqrt(2 * ship:body:mu * rp / ra / (ra + rp)).
    local vd to sqrt(2 * ship:body:mu * rd / ra / (ra + rd)).
    add node(ship:obt:eta:apoapsis + time, 0, 0, vd - va).
}

function changeAp {
    parameter destAp.
    local ra to ship:obt:apoapsis + ship:body:radius.
    local rp to ship:obt:periapsis + ship:body:radius.
    local rd to destAp + ship:body:radius.
    local va to sqrt(2 * ship:body:mu * ra / rp / (ra + rp)).
    local vd to sqrt(2 * ship:body:mu * rd / rp / (rp + rd)).
    add node(ship:obt:eta:periapsis + time, 0, 0, vd - va).
}

function circleAtAp {
    changePe(ship:obt:apoapsis).
}

function circleAtPe {
    changeAp(ship:obt:periapsis).
}

function fromCircleApAtTime {
    parameter apDest.
    parameter nodeTime.

    local rp to ship:obt:periapsis + ship:body:radius.
    local rd to apDest + ship:body:radius.

    local vDest to sqrt(2 * ship:body:mu * rd / rp / (rP + rd)).
    local vc to sqrt(ship:body:mu / rp).
    add node(nodeTime, 0, 0, vDest  - vc).
}

function tanlyToEanly {
    parameter argOrbit.
    parameter tanly.
    local e to argOrbit:eccentricity.

    local quad1 to arcCos((e + cos(tanly)) / (1 + e * cos(tanly))).
    if tanly > 180 {
        return 360 - quad1.
    }
    return quad1.
}

function eanlyToManly {
    parameter argOrbit.
    parameter eanly.
    local e to argOrbit:eccentricity.
    
    return eanly - e * sin(eanly) * constant:radtodeg.
}

function manlyToEanly {
    parameter argOrbit.
    parameter manly.
    local e to argOrbit:eccentricity.

    local e0 to manly.
    local ei to e0.
    from {local i is 0.} until i = 10 step {set i to i + 1.} do {
        local fi to ei - e * sin(ei) * constant:radtodeg - manly.
        local di to 1 - e * cos(ei).
        print fi + " -- " + di.
        set ei to ei - (fi / di).
    }

    return ei.
}

function eanlyToTanly {
    parameter argOrbit.
    parameter eanly.
    local e to argOrbit:eccentricity.

    local quad1 to arccos((cos(eanly) - e) / (1 - e * cos(eanly))).
    if eanly > quad1 {
        return 360 - quad1.
    }
    return quad1.
}

function fromEllipseApAtTime {
    parameter apDest.
    parameter nodeTime.

    local tanlyNow to obt:trueanomaly.
    local eanlyNow to tanlyToEanly(obt, tanlyNow).
    local manlyNow to eanlyToManly(obt, eanlyNow).

    print "T = " + tanlyNow + ", E = " + eanlyNow + ", M = " + manlyNow.

    local dt to nodeTime - time:seconds.
    local avgAngularV to 360 / obt:period.

    local manlyThen to mod(manlyNow + avgAngularV * dt, 360).
    local eanlyThen to manlyToEanly(obt, manlyThen).
    local tanlyThen to eanlyToTanly(obt, eanlyThen).

    print "T = " + tanlyThen + ", E = " + eanlyThen + ", M = " + manlyThen.

    add node(nodeTime, 0, 0, 0).
}

function calculateOrbitalElements {
    parameter o.
    parameter t.
    
    local avgAngularV to sqrt(o:body:mu / (o:semimajoraxis ^ 3)).
    local meanAnamoly to avgAngularV * (o:period - o:eta:periapsis).
    print "N = " + avgAngularV + ", Mrad = " + meanAnamoly.
    local e to o:eccentricity.
    print "e = " + e.
    local tanly to meanAnamoly + 2 * e * sin(meanAnamoly) 
        + 1.25 * (e^2) * sin(2* meanAnamoly).
    print "True Anamoly = " + tanly.
    local eccentricAnamoly to arccos((e + cos(tanly))/ (1 + e * cos(tanly))).
    print "E = " + eccentricAnamoly.
}