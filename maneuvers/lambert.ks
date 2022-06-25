@LAZYGLOBAL OFF.

runOncePath("0:common/orbital.ks").
runOncePath("0:common/math.ks").

function lambert {
    parameter obtable1.
    parameter obtable2. 
    parameter offset. // r n p
    parameter startTime.
    parameter flightDuration.
    parameter allowLong.

    local results to lexicon().
    set results["ok"] to false.

    local obt1 to obtable1:obt.
    if obt1:body <> obtable2:obt:body {
        print "Orbits must have same body.".
        return results.
    }
    local focus to obt1:body.
    local endTime to startTime + flightDuration.

    local pi to constant:pi.
    local p1 to positionAt(obtable1, startTime) - focus:position.
    local p2 to positionAt(obtable2, endTime) - focus:position.

    local pro2 to velocityAt(obtable2, endTime):orbit:normalized.
    local norm2 to vCrs(pro2, p2):normalized.
    local rad2 to vCrs(norm2, pro2):normalized.
    set p2 to p2 + offset:x * rad2 + offset:y * norm2 + offset:z * pro2.
    // print "P1 = " + p1:mag.
    // print "P2 = " + p2:mag.

    local cvec to p2 - p1.
    local r1 to p1:mag.
    local r2 to p2:mag.
    local radRat to r2 / r1.

    local globalUp to v(0, 1, 0).
    local dTheta to vectorAngleAroundR(p1, globalUp, p2).
    local cAng to vectorAngleAroundR(p1, globalUp, cvec).
    local nRef to sqrt(focus:mu / (r1 ^ 3)).
    local tauS to flightDuration * nRef.
    local isShort to dTheta <= pi.

    // print "RadRat = " + radRat.
    // print "Theta = " + dTheta.
    // print "Nref = " + nRef.
    // print "TauS = " + tauS.

    local ef to (r1 - r2) / cvec:mag.
    // print "Ef = " + ef.
    local ep to sqrt(1 - ef^2).
    local eh to ep.

    if not (isShort or allowLong) { 
        return results. 
    }
    
    if not isShort {
        local emax to -1 / cosR(dTheta / 2).
        set eh to sqrt(emax^2 - ef^2).
        set eh to min(ep, eh) .
    }
    // print "E limits = " + -1 * eh + " < eF < "+ ep.

    // local toX to { parameter et_. return et_. }.
    local fromX to { parameter x_. return x_. }.

    // set toX to {
    //     parameter et_.
    //     local coeff to ep * eh / (ep + eh).
    //     local limits to (et_ + eh) / (ep - eh). 
    //     return coeff * ln(limits * ep / eh).
    // }.
    set fromX to {
        parameter x_.
        local bigX to constant:e ^ (x_ * (1 / eh + 1 / ep)).
        return ep * eh * (bigX - 1) / (ep + eh * bigX).
    }.

    // find good eT
    local x to 0.
    local dX to 0.0001.
    local cDimless to cvec:mag / r1.
    local epsilon to (1 / 10 ^ 12) / min(1, tauS).
    local yS to ln(tauS).
    local et to 0.
    local kLimit to 12.
    from { local k to 0. } until k > kLimit step {set k to k + 1. } do {
        set et to fromX(x).
        local ecc to sqrt(ef ^2 + et ^2).
        if ecc * ecc > .999 {
            return results.
        }
        // print "Try et = " + et + ", " + x.
 
        local tau to dimensionlessKepler(radRat, cDimless, cAng, dTheta, ef, et).
       
        local y to ln(tau).
        if abs(y - yS) < epsilon {
            // print "Found good orbit".
            break.
        }

        // differentiate numerically
        local x_p to x + dX.
        local et_p to fromX(x_p).

        local tau_p to dimensionlessKepler(radRat, cDimless, cAng, dTheta, ef, et_p).
        local y_p to ln(tau_p).
        local dY_dX to (y_p - y) / dX.

        // nr iteration
        set x to x + (yS - y) / dY_dX.

        if k = kLimit {
            return results.
        }
    }

    local ic to cvec:normalized.
    local ih to -1 * vCrs(p1, p2):normalized.
    local ip to -1 * vCrs (ih, ic).
    local evec to et * ip + ef * ic.
    // print ih.
    
    // build orbit
    local ecc to evec:mag.
    //print "Ip = " + ip.
    //vecdraw(focus:position + p1, ip * 1000000, rgb(0, 0, 1), "ip", 1.0, true).
    //print "Ic = " + ic.
    //vecdraw(focus:position + p1, ic * 1000000, rgb(0, 0, 1), "ic", 1.0, true).
    //print "Ih = " + ih.
    //vecdraw(focus:position + p1, ih * 1000000, rgb(0, 0, 1), "ih", 1.0, true).
    // print "Inc = " + inc.
    // print "Ecc = " + ecc.
    local funMajor to (r1 + r2) / 2.
    local funRectum to funMajor * (1 - ef ^2).
    local rectum to funRectum - sinR(dTheta) * et * (r1 * r2) / cvec:mag.
    local semiMajor to rectum / (1 - ecc ^ 2).
    // print "SemiMajor = " + semiMajor.
    //local periodS to 2 * pi * sqrt(semiMajor ^ 3 / obt1:body:mu).
    // print "Period = " + timespan(periodS):full.
    //local nodeDir to -1 * vCrs(ih, globalUp).
    //local longANode to vectorAngleAround(solarPrimeVector, globalUp, nodeDir).
    //print "LongANode = " + longANode.
    //vecdraw(focus:position, -2 * semiMajor * evec , rgb(0, 1, 1), "ev", 1.0, true).
    //local argPe to vectorAngleAround(nodeDir, ih, evec).
    //print "ArgPe = " + argPe.
    // print "V = " + tangV.
    local function transVAtPos {
        parameter pos_.
        local tangV to sqrt(body:mu * (2 / pos_:mag - 1 / semiMajor)).
        local transTanly to vectorAngleAroundR(evec, ih, pos_).
        // print "Transit True Anomaly = " + transTanly.
        local flightA to arcTan2R(ecc * sinR(transTanly), 
            1 + ecc * cosR(transTanly)).
        // print "Flight Angle = " + flightA.

        local transCircle to vCrs(pos_, ih):normalized.
        //print "Circular trans = " + transCircle.
        local transOut to pos_:normalized.
        local transV to tangV * (transCircle * cosR(flightA)
            + transOut * sinR(flightA)).
        return transV.
    }

    local ejectVec to transVAtPos(p1).
    local startVec to velocityAt(obtable1, startTime):orbit.
    //print "Out trans = " + transOut.
    //print "Trans vec = " + transVec.
    //print "Start vec = " + startVec.
    local startPro to startVec:normalized.
    local startRad to (p1 - vDot(p1, startPro) * startPro):normalized.
    local startNorm to vCrs(startPro, startRad).
    local burnVec to ejectVec - startVec.
    local burnPro to vdot(burnVec, startPro).
    local burnNorm to vdot(burnVec, startNorm).
    local burnRad to vdot(burnVec, startRad).
    set results["ok"] to true.
    set results["burnVec"] to burnVec.
    set results["burnNode"] to node(startTime, burnRad, burnNorm, burnPro).

    set results["matchVec"] to velocityAt(obtable2, endTime):orbit 
        - transVAtPos(p2).
    return results.
}

function dimensionlessKepler {
    parameter rho, c, wc, dTheta, ef, et.
    local ecc to sqrt (ef ^ 2 + et ^ 2).
    //print " ecc = " + ecc.

    // dimensionless mean motion 
    local funMajor to (1 + rho) / 2.
    //print " af = " + funMajor.
    local funRectum to funMajor * (1 - ef ^2).
    //print " pf = " + funRectum.
    local rectum to funRectum - sinR(dTheta) * et * rho / c.
    //print " p = "  + rectum.
    local semiMajor to rectum / (1 - ecc ^ 2).
    //print " a = " + semiMajor.
    local meanMotion to semiMajor ^ (-3/2).
    //print " dimlessMeanMotion = " + meanMotion.

    // mean anomaly angle
    local function dimlessManly {
        parameter tanly.
        local eanly to arcCosR((ecc + cosR(tanly)) / (1 + ecc * cosR(tanly))).
        if tanly > constant:pi {
            set eanly to 2 * constant:pi - eanly.
        }
        return eanly - ecc * sinR(eanly).
    }

    local tanlyReverse to arcTan2R(ef * sinR(wc) + et * cosR(wc),
        ef * cosR(wc) - et * sinR(wc)).
    local p1Tanly to -1 * tanlyReverse.
    local p2Tanly to dTheta - tanlyReverse.
    local p1Manly to dimlessManly(p1Tanly).
    local p2Manly to dimlessManly(p2Tanly).
    // print " tanlyReverse = " + tanlyReverse.
    // print " p2Tanly  = " + p2Tanly.
    // print "p1Manly = " + p1Manly.
    // print " p2Manly = " + p2Manly.

    local t to (p2Manly - p1Manly) / meanMotion.
    return t.
}

function landingOptimizer {
    // combine with lambert
    parameter obtable1.
    parameter pos2. 
    parameter startTime.
    parameter flightDuration.
    parameter allowLong.

    local results to lexicon().
    set results["ok"] to false.

    local obt1 to obtable1:obt.
    local focus to obt1:body.
    local endTime to startTime + flightDuration.

    local pi to constant:pi.
    local p1 to positionAt(obtable1, startTime) - focus:position.
    local p2 to pos2 - focus:position.

    // print "P1 = " + p1:mag.
    // print "P2 = " + p2:mag.

    local cvec to p2 - p1.
    local r1 to p1:mag.
    local r2 to p2:mag.
    local radRat to r2 / r1.

    local startVec to velocityAt(obtable1, startTime):orbit.
    //print "Out trans = " + transOut.
    //print "Trans vec = " + transVec.
    //print "Start vec = " + startVec.
    local startPro to startVec:normalized.
    local startRad to (p1 - vDot(p1, startPro) * startPro):normalized.
    local startNorm to vCrs(startPro, startRad).

    local dTheta to vectorAngleAroundR(p1, startNorm, p2).
    local cAng to vectorAngleAroundR(p1, startNorm, cvec).
    local isShort to dTheta <= pi.

    // print "RadRat = " + radRat.
    print "Theta = " + dTheta.
    // print "Nref = " + nRef.
    // print "TauS = " + tauS.

    local ef to (r1 - r2) / cvec:mag.
    // print "Ef = " + ef.
    local ep to sqrt(1 - ef^2).
    local eh to ep.

    if not (isShort or allowLong) { 
        return results. 
    }
    
    if not isShort {
        local emax to -1 / cosR(dTheta / 2).
        set eh to sqrt(emax^2 - ef^2).
        set eh to min(ep, eh) .
    }
    // print "E limits = " + -1 * eh + " < eF < "+ ep.

    // local toX to { parameter et_. return et_. }.
    local fromX to { parameter x_. return x_. }.

    set fromX to {
        parameter x_.
        local bigX to constant:e ^ (x_ * (1 / eh + 1 / ep)).
        return ep * eh * (bigX - 1) / (ep + eh * bigX).
    }.
    local flightAOp to {
        parameter wc_, ef_, et_.
        local tanlyReverse to arcTan2R(ef_ * sinR(wc_) + et_ * cosR(wc_),
            ef * cosR(wc_) - et_ * sinR(wc_)).
        local p1Tanly to -1 * tanlyReverse.
        local ecc_ to ef_ ^ 2 + et_ ^ 2.
        local flightA to arcTan2R(ecc_ * sinR(p1Tanly), 
            1 + ecc_ * cosR(p1Tanly)).
        return flightA.
    }.

    // find good eT
    local x to 0.
    local dX to 0.0001.
    local epsilon to (1 / 10 ^ 12).
    local yS to 0.
    local et to 0.
    local kLimit to 12.
    from { local k to 0. } until k > kLimit step {set k to k + 1. } do {
        set et to fromX(x).
        local ecc to sqrt(ef ^2 + et ^2).
        if ecc * ecc > .999 {
            return results.
        }

        local y to flightAOp(cAng, ef, et).
        if abs(y - yS) < epsilon {
            // print "Found good orbit".
            break.
        }

        // differentiate numerically
        local x_p to x + dX.
        local et_p to fromX(x_p).

        local y_p to flightAOp(cAng, ef, et_p).
        local dY_dX to (y_p - y) / dX.

        // nr iteration
        set x to x + (yS - y) / dY_dX.

        if k = kLimit {
            return results.
        }
    }

    local ic to cvec:normalized.
    local ih to -1 * vCrs(p1, p2):normalized.
    local ip to -1 * vCrs (ih, ic).
    local evec to et * ip + ef * ic.
    // print ih.
    
    // build orbit
    local ecc to evec:mag.
    //print "Ip = " + ip.
    //vecdraw(focus:position + p1, ip * 1000000, rgb(0, 0, 1), "ip", 1.0, true).
    //print "Ic = " + ic.
    //vecdraw(focus:position + p1, ic * 1000000, rgb(0, 0, 1), "ic", 1.0, true).
    //print "Ih = " + ih.
    //vecdraw(focus:position + p1, ih * 1000000, rgb(0, 0, 1), "ih", 1.0, true).
    // print "Inc = " + inc.
    // print "Ecc = " + ecc.
    local funMajor to (r1 + r2) / 2.
    local funRectum to funMajor * (1 - ef ^2).
    local rectum to funRectum - sinR(dTheta) * et * (r1 * r2) / cvec:mag.
    local semiMajor to rectum / (1 - ecc ^ 2).
    // print "SemiMajor = " + semiMajor.
    //local periodS to 2 * pi * sqrt(semiMajor ^ 3 / obt1:body:mu).
    // print "Period = " + timespan(periodS):full.
    //local nodeDir to -1 * vCrs(ih, globalUp).
    //local longANode to vectorAngleAround(solarPrimeVector, globalUp, nodeDir).
    //print "LongANode = " + longANode.
    //vecdraw(focus:position, -2 * semiMajor * evec , rgb(0, 1, 1), "ev", 1.0, true).
    //local argPe to vectorAngleAround(nodeDir, ih, evec).
    //print "ArgPe = " + argPe.
    // print "V = " + tangV.
    local function transVAtPos {
        parameter pos_.
        local tangV to sqrt(body:mu * (2 / pos_:mag - 1 / semiMajor)).
        local transTanly to vectorAngleAroundR(evec, ih, pos_).
        // print "Transit True Anomaly = " + transTanly.
        local flightA to arcTan2R(ecc * sinR(transTanly), 
            1 + ecc * cosR(transTanly)).
        // print "Flight Angle = " + flightA.

        local transCircle to vCrs(pos_, ih):normalized.
        //print "Circular trans = " + transCircle.
        local transOut to pos_:normalized.
        local transV to tangV * (transCircle * cosR(flightA)
            + transOut * sinR(flightA)).
        return transV.
    }

    local ejectVec to transVAtPos(p1).
    local burnVec to ejectVec - startVec.
    local burnPro to vdot(burnVec, startPro).
    local burnNorm to vdot(burnVec, startNorm).
    local burnRad to vdot(burnVec, startRad).
    set results["ok"] to true.
    set results["burnVec"] to burnVec.
    set results["burnNode"] to node(startTime, burnRad, burnNorm, burnPro).

    return results.
}

// if hyper are allowed
    // if isShort {
    //     set toX to {
    //         parameter et_.
    //         return -1 * ep * ln(1 - et_ / ep).
    //     }.
    //     set fromX to {
    //         parameter x_.
    //         return ep * (1 - constant:e ^ (1 - x_ / ep)).
    //     }.
    // } else {
    //     set toX to {
    //         parameter et_.
    //         local coeff to ep * eh / (ep + eh).
    //         local limits to (et_ + eh) / (ep - eh). 
    //         return coeff * ln(limits * ep / eh).
    //     }.
    //     set fromX to {
    //         parameter x_.
    //         local bigX to constant:e ^ (x_ * (1 / eh + 1/ ep)).
    //         return ep * eh * (bigX - 1) / (ep + eh * bigX).
    //     }.
    // }