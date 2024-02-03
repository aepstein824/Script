@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/math.ks").
runOncePath("0:test/test_utils.ks").

function lambertIntercept {
    parameter obtable1.
    parameter obtable2.
    parameter startTime.
    parameter flightDuration.
    parameter ignorePlane to false.

    local obt1 to obtable1:obt.
    if obt1:body <> obtable2:obt:body {
        return testError("Orbits must have same body.").
    }
    if detimestamp(startTime) < (time:seconds - 1) {
        return testError("Negative start " + (startTime - time:seconds < 0)).
    }
    if flightDuration < 0 {
        return testError("Negative duration " + flightDuration).
    }

    local endTime to startTime + flightDuration.
    local p2 to positionAt(obtable2, endTime) - obt1:body:position.
    if ignorePlane {
        local norm1 to normOf(obtable1:obt).
        local norm2 to normOf(obtable2:obt).
        local planeNode to vCrs(norm1, norm2).
        local rotateAngle to vectorAngleAround(norm2, planeNode, norm1).
        set p2 to rotateVecAround(p2, planeNode, rotateAngle).
    }
    local factory to lambertInterceptFitnessFactory@.
    set factory to factory:bind(detimestamp(flightDuration)).

    local res to lambert(obtable1, p2, startTime, true, factory).
    if res:ok {
        set res:matchVec to velocityAt(obtable2, endTime):orbit - res:vAtP2.
    }

    return res.
}

function lambertInterceptFitnessFactory {
    parameter flightDuration, r1, r2, mu, dTheta, cvec, cang, ef.

    local radRat to r2 / r1.
    local nRef to sqrt(mu / (r1 ^ 3)).
    local tauS to flightDuration * nRef.
    local yS to ln(tauS).
    local cDimless to cvec:mag / r1.
    local epsilon to 1e-10 / min(1, tauS).

    local function fitness {
        parameter et.
        local tau to 0.
        set tau to dimlessKepler(radRat, cDimless, cang, dTheta, ef, et).
        local y to ln(max(tau, 0.00001)).
        return y - yS. 
    }

    return lexicon("epsilon", epsilon, "fitness", fitness@).
}

function lambertPosOnly {
    parameter obtable1.
    parameter p2.
    parameter startTime.
    parameter flightDuration.


    local factory to lambertInterceptFitnessFactory@.
    set factory to factory:bind(detimestamp(flightDuration)).

    local res to lambert(obtable1, p2, startTime, true, factory).
    return res.
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

    return lexicon("epsilon", .01, "fitness", fitness@).
}

function lambert {
    parameter obtable1.
    parameter p2. 
    parameter startTime.
    parameter allowLong.
    parameter fitnessFactory.

    local results to lex().

    local obt1 to obtable1:obt.
    local focus to obt1:body.

    local p1 to positionAt(obtable1, startTime) - focus:position.
    local startVec to velocityAt(obtable1, startTime):orbit.
    local p1Rnp to obtRnpFromPV(p1, startVec).
    // clearVecDraws().
    // vecdraw(focus:position, p1, rgb(0, 0, 1), "p1", 1.0, true).
    // vecdraw(focus:position, p2, rgb(0, 1, 0), "p2", 1.0, true).

    // print "P1 = " + p1:mag.
    // print "P2 = " + p2:mag.

    local cvec to p2 - p1.
    local r1 to p1:mag.
    local r2 to p2:mag.
    
    local ih to -1 * vCrs(p1, p2):normalized.
    if vdot(ih, p1Rnp:upvector) < 0 {
        set ih to -ih.
    }
    // We rotate right hand around the normal, but all of the vectorAngleAround
    // calls are left handed. Something is wrong, but until I can test further,
    // I'm hacking this to make my interstellar trip work.
    if obtable1:obt:eccentricity > 1 {
        set ih to -1 * vCrs(p1, p2):normalized.
    }

    local dTheta to vectorAngleAroundR(p1, ih, p2).
    local isShort to dTheta <= kPi.

    // print "Theta = " + dTheta.

    local ef to (r1 - r2) / cvec:mag.
    // print "Ef = " + ef.
    local ep to sqrt(1 - ef^2).
    local eh to ep.

    if not (isShort or allowLong) { 
        return testError("Short ellipses not allowed"). 
    }
    
    if not isShort {
        local emax to -1 / cosR(dTheta / 2).
        set eh to sqrt(emax^2 - ef^2).
    }
    // print "E limits = " + -1 * eh + " < eT < "+ ep.

    local fromX to { parameter x_. return x_. }.
    if isShort {
        set fromX to {
            parameter x_.
            return -ep * expm1(-x_ / ep).
        }.
    } else {
        set fromX to {
            parameter x_.
            local bigX to kEul ^ (x_ * (1 / eh + 1 / ep)).
            return ep * eh * (bigX - 1) / (ep + eh * bigX).
        }.
    }

    local cAng to vectorAngleAroundR(p1, ih, cvec).
    local specifics to fitnessFactory:call(r1, r2, focus:mu, dTheta, cvec, cang,
        ef).

    // find good eT
    local epsilon to specifics:epsilon.
    local x to 0.
    local dX to 1e-6.
    local et to 0.
    local kLimit to 12.
    for k in range(kLimit) {
        set et to fromX(x).

        // print " Try et = " + et + ", " + x.
 
        local y to specifics:fitness:call(et).
        if abs(y) < epsilon {
            // print k.
            break.
        }

        // differentiate numerically
        local x_p to x + dX.
        local et_p to fromX(x_p).

        local y_p to specifics:fitness:call(et_p).
        local dY_dX to (y_p - y) / dX.
        if abs(dy_dx) < 1e-12 {
            return testError("Aborting since dy_dx = " + dy_dx
                + " " + y + ", " + y_p).
        }

        // nr iteration
        set x to x - y / dY_dX.

        if k = kLimit {
            break.
            // return testError("Hit iteration limit but error is " + abs(y)).
        }
    }

    local ic to cvec:normalized.
    local ip to -1 * vCrs (ih, ic).
    local evec to et * ip + ef * ic.
    // print ih.
    
    // build orbit
    // eccentricity vector points from ap to pe
    local ecc to evec:mag.
    // print "calculated ecc " + round(ecc, 3).
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
        local tangV to sqrt(focus:mu * (2 / pos_:mag - 1 / semiMajor)).
        local transTanly to vectorAngleAroundR(evec, ih, pos_).
        // print "Transit True Anomaly = " + transTanly.
        local flightA to arcTan2R(ecc * sinR(transTanly), 
            1 + ecc * cosR(transTanly)).
        // print "Flight Angle = " + flightA.

        local transCircle to vCrs(pos_, ih):normalized.
        // print "Circular trans = " + transCircle.
        local transOut to pos_:normalized.
        local transV to tangV * (transCircle * cosR(flightA)
            + transOut * sinR(flightA)).
        return transV.
    }

    local ejectVec to transVAtPos(p1).
    // print "ejectVec " + ejectVec.
    // print "startVec " + startVec.

    local burnVec to ejectVec - startVec.
    local burnRnp to p1Rnp:inverse * burnVec.

    set results["ok"] to true.
    set results["burnVec"] to burnVec.
    set results["burnNode"] to node(startTime, burnRnp:x, burnRnp:y, burnRnp:z).
    set results["norm"] to ih.
    set results:vAtP2 to transVAtPos(p2).
    return results.
}

function dimlessEllipse {
    parameter p1Tanly, p2Tanly.
    parameter rho, c, dTheta, ef, et.

    local p1TanlyDeg to p1Tanly * constant:radtodeg.
    local p2TanlyDeg to p2Tanly * constant:radtodeg.

    local ecc2 to ef ^ 2 + et ^ 2.
    local ecc to sqrt(ecc2).
    local function dimlessManly {
        parameter tanly.
        local eanly to arctan2(sqrt(1 - ecc2) * sin(tanly), ecc+cos(tanly)).
        return eanly - ecc * sin(eanly) * 57.2957795131.
    }

    // semiMajor is ((1 + ecc * cosR(p1Tanly)) / (1 - ecc2)).
    local meanMotion to constant:radtodeg * (
        (1 - ecc2) / (1 + ecc * cos(p1TanlyDeg))
    ) ^ (3/2).

    local p1ManlyDeg to dimlessManly(p1TanlyDeg).
    local p2ManlyDeg to dimlessManly(p2TanlyDeg).
    local manlyDiff to posmod(p2ManlyDeg - p1ManlyDeg, 360).

    local t to manlyDiff / meanMotion.
    return t.
}

function dimlessHyper {
    parameter p1Tanly, p2Tanly.
    parameter rho, c, dTheta, ef, et.

    local ecc2 to ef ^ 2 + et ^ 2.
    local ecc to sqrt(ecc2).

    local function dimlessManly {
        parameter tanly.
        local cosTanly to cosR(tanly).
        local cosHF to (ecc + cosTanly) / (1 + ecc * cosTanly).
        local sgnTanly to sgn(tanly).
        local F to sgnTanly * arcCosHR(cosHF).
        local sinHF to sgnTanly * sqrt((cosHF  - 1)
            / (cosHF + 1)) * (cosHF + 1).
        local manly to ecc * sinHF - F.
        return manly.
    }

    // dimless mean motion 
    // this formula relies on radius being 1 for p1
    local semiMajor to (1 + ecc * cosR(p1Tanly)) / (1 - ecc2).
    if semiMajor >= 0 {
        print " fixing semimajor in lambert " + semiMajor + " ecc " + ecc.
        return 0.
    }
    local meanMotion to (-semiMajor) ^ (-3/2).

    local p1Manly to dimlessManly(p1Tanly).
    local p2Manly to dimlessManly(p2Tanly).

    local t to (p2Manly - p1Manly) / meanMotion.
    return t.
}

function dimlessKepler {
    parameter rho, c, wc, dTheta, ef, et.
    local sinWc to sinR(wc).
    local cosWc to cosR(wc).
    local tanlyReverse to arcTan2R(
        ef * sinWc + et * cosWc,
        ef * cosWc - et * sinWc).
    local p1Tanly to -1 * tanlyReverse.
    local p2Tanly to dTheta - tanlyReverse.
    // print " tanlyReverse = " + tanlyReverse.
    // print " p1Tanly  = " + p1Tanly.
    // print " p2Tanly  = " + p2Tanly.

    local ecc2 to ef ^ 2 + et ^ 2.
    if ecc2 < 1 {
        return dimlessEllipse(p1Tanly, p2Tanly, rho, c, dTheta, ef, et).
    } else {
        return dimlessHyper(p1Tanly, p2Tanly, rho, c, dTheta, ef, et).
    }
}
