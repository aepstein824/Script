@LAZYGLOBAL OFF.

runOncePath("0:common/orbital.ks").
runOncePath("0:common/math.ks").

local pi to constant:pi.
local eul to constant:e.
local badResult to lexicon("ok", false).

function lambertIntercept {
    parameter obtable1.
    parameter obtable2.
    parameter offset. // r n p
    parameter startTime.
    parameter flightDuration.

    local obt1 to obtable1:obt.
    if obt1:body <> obtable2:obt:body {
        print "Orbits must have same body.".
        return badResult:copy().
    }
    local endTime to startTime + flightDuration.

    local p2 to positionAt(obtable2, endTime) - obt1:body:position.
    local pro2 to velocityAt(obtable2, endTime):orbit:normalized.
    local norm2 to vCrs(pro2, p2):normalized.
    local rad2 to vCrs(norm2, pro2):normalized.
    set p2 to p2 + offset:x * rad2 + offset:y * norm2 + offset:z * pro2.

    local factory to lambertInterceptFitnessFactory@.
    set factory to factory:bind(flightDuration).

    local res to lambert(obtable1, p2, startTime, true, factory).

    set res:matchVec to velocityAt(obtable2, endTime):orbit - res:vAtP2.
    return res.
}

function lambertInterceptFitnessFactory {
    parameter flightDuration, r1, r2, mu, dTheta, cvec, cang, ef.

    local radRat to r2 / r1.
    local nRef to sqrt(mu / (r1 ^ 3)).
    local tauS to flightDuration * nRef.
    local cDimless to cvec:mag / r1.
    local epsilon to (1 / 10 ^ 8) / min(1, tauS).
    local yS to ln(tauS).

    local function fitness {
        parameter et.
        local tau to dimensionlessKepler(radRat, cDimless, cang, dTheta, ef, et).
        local y to ln(tau).
        return y - yS. 
    }

    return lexicon("epsilon", epsilon, "fitness", fitness@).
}

function lambertLanding {
    parameter obtable1.
    parameter p2.
    parameter startTime.

    local res to lambert(obtable1, p2, startTime, true, 
        lambertLandingFitnessFactory@). 

    return res.
}

function lambertLandingFitnessFactory {
    parameter r1, r2, mu, dTheta, cvec, cang, ef.

    local function fitness {
        parameter et.
        local tanlyReverse to arcTan2R(ef * sinR(cang) + et * cosR(cang),
            ef * cosR(cang) - et * sinR(cang)).
        local p1Tanly to -1 * tanlyReverse.
        local ecc_ to ef ^ 2 + et ^ 2.
        local flightA to arcTan2R(ecc_ * sinR(p1Tanly), 
            1 + ecc_ * cosR(p1Tanly)).
        return flightA.
    }.

    return lexicon("epsilon", 1/10^3, "fitness", fitness@).
}

function lambert {
    parameter obtable1.
    parameter p2. 
    parameter startTime.
    parameter allowLong.
    parameter fitnessFactory.

    local results to badResult:copy().

    local obt1 to obtable1:obt.
    local focus to obt1:body.

    local p1 to positionAt(obtable1, startTime) - focus:position.
    // clearVecDraws().
    // vecdraw(focus:position, p1, rgb(0, 0, 1), "p1", 1.0, true).
    // vecdraw(focus:position, p2, rgb(0, 1, 0), "p2", 1.0, true).

    print "P1 = " + p1:mag.
    print "P2 = " + p2:mag.

    local cvec to p2 - p1.
    local r1 to p1:mag.
    local r2 to p2:mag.

    
    local ih to -1 * vCrs(p1, p2):normalized.

    local dTheta to vectorAngleAroundR(p1, ih, p2).
    local isShort to dTheta <= pi.

    print "Theta = " + dTheta.

    local ef to (r1 - r2) / cvec:mag.
    print "Ef = " + ef.
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

    local fromX to { parameter x_. return x_. }.

    set fromX to {
        parameter x_.
        local bigX to eul ^ (x_ * (1 / eh + 1 / ep)).
        return ep * eh * (bigX - 1) / (ep + eh * bigX).
    }.

    local cAng to vectorAngleAroundR(p1, ih, cvec).
    local specifics to fitnessFactory:call(r1, r2, focus:mu, dTheta, cvec, cang, ef).

    // find good eT
    local epsilon to specifics:epsilon.
    local x to 0.
    local dX to 0.0001.
    local et to 0.
    local kLimit to 12.
    from { local k to 0. } until k > kLimit step {set k to k + 1. } do {
        set et to fromX(x).
        local ecc to sqrt(ef ^2 + et ^2).

        print "Try et = " + et + ", " + x.
        print "Ecc " + ecc.
        if ecc > .999599 {
            print "aborting due to high ecc".
            return results.
        }
 
        local y to specifics:fitness:call(et).
        if abs(y) < epsilon {
            print "Found good orbit".
            break.
        }

        // differentiate numerically
        local x_p to x + dX.
        local et_p to fromX(x_p).

        local y_p to specifics:fitness:call(et_p).
        local dY_dX to (y_p - y) / dX.

        print "y = " + y + ", dy = " + dY_dX.

        // nr iteration
        set x to x - y / dY_dX.

        if k = kLimit {
            return results.
        }
    }

    local ic to cvec:normalized.
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
    set results:vAtP2 to transVAtPos(p2).
    return results.
}

function dimlessManly {
    parameter tanly, ecc.
    local cosTanly to cosR(tanly).
    local eanly to arcCosR((ecc + cosTanly) / (1 + ecc * cosTanly)).
    if tanly > pi {
        set eanly to 2 * pi - eanly.
    }
    return eanly - ecc * sinR(eanly).
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

    local sinWc to sinR(wc).
    local cosWc to cosR(wc).
    local tanlyReverse to arcTan2R(ef * sinWc + et * cosWc,
        ef * cosWc - et * sinWc).
    local p1Tanly to -1 * tanlyReverse.
    local p2Tanly to dTheta - tanlyReverse.
    local p1Manly to dimlessManly(p1Tanly, ecc).
    local p2Manly to dimlessManly(p2Tanly, ecc).
    if p2Manly < p1Manly {
        set p2Manly to p2Manly + 2 * pi.
    }
    // print " tanlyReverse = " + tanlyReverse.
    // print " p2Tanly  = " + p2Tanly.
    // print "p1Manly = " + p1Manly.
    // print " p2Manly = " + p2Manly.

    local t to (p2Manly - p1Manly) / meanMotion.
    return t.
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


    // local toX to { parameter et_. return et_. }.
    // set toX to {
    //     parameter et_.
    //     local coeff to ep * eh / (ep + eh).
    //     local limits to (et_ + eh) / (ep - eh). 
    //     return coeff * ln(limits * ep / eh).
    // }.
