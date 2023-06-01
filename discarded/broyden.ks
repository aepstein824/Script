function optimizeApproxGradient {
    parameter f, x, dx.

    local f__ to f(x).
    local fp_ to f(x + v(dx, 0, 0)).
    local f_p to f(x + v(0, dx, 0)).
    local dfdx0  to (fp_ - f__) / dx.
    local dfdx1 to (f_p - f__) / dx.
    local grad to v(dfdx0, dfdx1, 0).

    return lex("f__", f__, "grad", grad).
}

function optimizeApproxJacobian {
    parameter f, x, dx.

    local dx0 to v(dx, 0, 0).
    local dx1 to v(0, dx, 0).
    local f__ to f(x).
    local fp_ to f(x + dx0).
    local f_p to f(x + dx1).
    local fpp to f(x + dx0 + dx1).
    local fn_ to f(x - dx0).
    local f_n to f(x - dx1).
    local dfdx0  to (fp_ - f__) / dx.
    local dfdx1 to (f_p - f__) / dx.
    local dfdx0p to (fpp - f_p) / dx.
    local df2dx00  to (fp_ - 2 * f__ + fn_) / dx / dx.
    local df2dx11 to (f_p - 2 * f__ + f_n) / dx / dx.
    local df2dx01 to (dfdx0p - dfdx0) / dx.
    local det to (df2dx11 * df2dx00 - df2dx01 ^ 2).
    local inv to (1 / det) * v(df2dx11, -df2dx01, df2dx00).
    local grad to v(dfdx0, dfdx1, 0).

    return lex("f__", f__, "grad", grad, "inv", inv).
}


function optimizeBroydenDiffs {
    parameter f, xI, dx to 1e-4, eps to 1e-6.

    function matVecMult {
        parameter mat, vec.
        return v(
            mat:x * vec:x + mat:y * vec:y,
            mat:y * vec:x + mat:z * vec:y, 0
        ).
    }
    function vecRowColMult {
        parameter vec, vecT.
        // we're assuming this makes a symmetric matrix in this context
        local symm to abs((vec:x * vecT:y) - (vec:y * vecT:x)) < 10.
        // print symm + " " + (vec:x * vecT:y) + " vs " + (vec:y * vecT:x).
        return v(
            vec:x * vecT:x,
            vec:x * vecT:y,
            vec:y * vecT:y).
    }
    local x to xI.
    local i to 0.
    local jacobApprox to optimizeApproxJacobian(f, xI, dx).
    local grad to jacobApprox:grad.
    local jinv to jacobApprox:inv.
    print "------ jinv " + jinv.
    until False {
        local update to -.7 * matVecMult(jinv, grad).
        local xnew to x + update.
        print "-Evaluating with " + timeRoundStr(xnew:x - time:seconds)
            + " - " + timeRoundStr(xnew:y).
        local gradnew to optimizeApproxGradient(f, xnew, dx):grad.
        local y to gradnew:mag.
        if y < eps or update:mag < dx or i > 40 {
            print " i " + i.
            print " x " + x.
            print " y " + y.
            return xnew.
        }
        local dgrad to gradnew - grad.
        local jfgrad to matVecMult(jinv, dgrad).
        // this is a column vector
        local jupdateLeft to ((update - jfgrad) / vdot(update, jfgrad)).
        // this is a row vector
        local jupdateRight to matVecMult(jinv, update).
        local jupdate to vecRowColMult(jupdateLeft, jupdateRight).

        // local jupdate to vecRowColMult(
        //     (update - jfgrad) / vdot(dgrad, dgrad), dgrad).


        set jinv to jinv + jupdate.
        set x to xnew.
        set grad to gradnew.
        set i to i + 1.
    }
}

function optimizeNewton2d {
    parameter f, xI, dx to 1e-4, eps to 1e-10.

    local eps2 to eps * eps.
    local tries to 10.
    local x to xI.
    for k in range(tries) {
        // print " --- ".
        local xzz to f(x).
        local xpz to f(x + v(dx, 0, 0)).
        local xzp to f(x + v(0, dx, 0)).
        local xnz to f(x + v(-dx, 0, 0)).
        local xzn to f(x + v(0, -dx, 0)).
        local dfdx0  to (xpz - xzz) / dx.
        local dfdx1 to (xzp - xzz) / dx.
        local df2dx0_2 to (xpz - 2 * xzz + xnz) / dx / dx.
        local df2dx1_2 to (xzp - 2 * xzz + xzn) / dx / dx.
        // print x.
        // print "dfdx0    " + dfdx0.
        // print "dfdx1    " + dfdx1.
        // print "df2dx0_2 " + df2dx0_2.
        // print "df2dx1_2 " + df2dx1_2.
        if dfdx0 ^ 2 + dfdx1 ^ 2 < eps2 {
            break.
        }

        local updateX0 to 0.
        if abs(df2dx0_2) > 0 {
            set updateX0 to dfdx0 / df2dx0_2.
        }
        local updateX1 to 0.
        if abs(df2dx1_2) > 0 {
            set updateX1 to dfdx1 / df2dx1_2.
        }
        // set x to x - 0.7 * v(updateX0, updateX1, 0).
        set x to x - vecClampMag(v(updateX0, updateX1, 0),
            max(abs(updateX0), abs(updateX1))).
    }
    return x.
}

// function optimizeNewton2d {
//     parameter f, xI, dx to 1e-4, eps to 1e-10.

//     local eps2 to eps * eps.
//     local tries to 10.
//     local x to xI.
//     for k in range(tries) {
//         local xzz to f(x).
//         local xpz to f(x + v(dx, 0, 0)).
//         local xzp to f(x + v(0, dx, 0)).
//         // local xpp to f(x + v(dx, dx, 0)).
//         local xnz to f(x + v(-dx, 0, 0)).
//         local xzn to f(x + v(0, -dx, 0)).
//         local dfdx0  to (xpz - xzz) / dx.
//         // local dfdx0p to (xpp - xzp) / dx.
//         local dfdx1 to (xzp - xzz) / dx.
//         local df2dx0_2 to (xpz - 2 * xzz + xnz) / dx / dx.
//         local df2dx1_2 to (xzp - 2 * xzz + xzn) / dx / dx.
//         // local df2dx01 to (dfdx0p - dfdx0) / dx.
//         // local df2dx01 to 0. // (dfdx0p - dfdx0) / dx.
//         print " --- ".
//         print x.
//         print "dfdx0    " + dfdx0.
//         // print "dfdx0p   " + dfdx0p.
//         print "dfdx1    " + dfdx1.
//         print "df2dx0_2 " + df2dx0_2.
//         print "df2dx1_2 " + df2dx1_2.
//         // print "df2dx01  " + df2dx01.
//         if dfdx0 ^ 2 + dfdx1 ^ 2 < eps2 {
//             break.
//         }

//         // local det to (df2dx1_2 * df2dx0_2 - df2dx01 ^ 2).
//         // if det = 0 {
//         //     print "Aborting due to 0 det".
//         //     return x.
//         // }
//         // print det.
//         // print v(df2dx0_2 * dfdx0 + df2dx01 * dfdx1,
//         //         df2dx01 * dfdx0 + df2dx1_2 * dfdx1, 0).

//         // print list(
//         //     (1/det) * (df2dx1_2),
//         //     (1/det) * (df2dx01),
//         //     (1/det) * (df2dx01),
//         //     (1/det) * (df2dx0_2)
//         // ).


//         // set x to x - (0.5 / det) * v(
//         //     df2dx1_2 * dfdx0 - df2dx01 * dfdx1,
//         //     -df2dx01 * dfdx0 + df2dx0_2 * dfdx1, 0).
//         set x to x - (0.9) * v(
//             dfdx0 / df2dx0_2,
//             dfdx1 / df2dx1_2, 0).
//     }
//     return x.
// }

function testNewton2d {
    local t to list().

    local function f0 {
        parameter x.
        return (x:x ^ 2 + x:y ^ 2).
    }
    t:add(testEq(optimizeNewton2d(f0@, v(1, 2, 0)), zeroV)).


    local function f1 {
        parameter x.
        local y to 2 ^ (x:mag ^ 2).
        // print x + " | " + y.
        return y.
    }
    t:add(testEq(optimizeNewton2d(f1@, v(1,1,0)), zeroV)).
    t:add(testEq(optimizeNewton2d(f1@, -unitX, 1e-3), zeroV)). 

    return t.
}

function testBroyden {
    local t to list().

    local function f0 {
        parameter x.
        return (x:x ^ 2 + kEul ^ (x:y ^ 2)).
    }
    t:add(testEq(optimizeBroydenDiffs(f0@, v(1, 0.2, 0), 1e-6), zeroV)).


    local function f1 {
        parameter x.
        local y to 2 ^ (x:mag ^ 2).
        // print x + " | " + y.
        return y.
    }
    // t:add(testEq(optimizeBroydenDiffs(f1@, v(1,1,0)), zeroV)).
    // t:add(testEq(optimizeBroydenDiffs(f1@, -unitX, 1e-3), zeroV)). 

    return t.
}

function interceptGridNR {
    parameter obtable1, obtable2, guessT, guessDur, di, dj.
    set guessT to detimestamp(guessT).
    set guessDur to detimestamp(guessDur).

    print (" LGrid 2dNR " + obtable2:name + " in "
        + timeRoundStr(detimestamp(guessT - time)) + ", " 
        + timeRoundStr(detimestamp(guessDur)) + " long").

    local best to lexicon().
    set best:totalV to 10 ^ 20.
    
    local extra to choose 2 if (obtable1:obt:body = sun) else 1.
    local lowI to -kIntercept:StartSpan * extra.
    local highI to kIntercept:StartSpan * extra + 1.
    local lowJ to -kIntercept:DurSpan * extra.
    local highJ to kIntercept:DurSpan * extra + 1.

    until guessT + di * lowI > time {
        print " advancing guess time".
        set guessT to guessT + di.
    }
    until guessDur + dj * lowJ > 1 {
        print " advancing guess dur".
        set guessDur to guessDur + dj.
    }

    local function f {
        parameter x.
        local lamb to lambertIntercept(obtable1, obtable2, x:x, x:y).
        if not lamb:ok {
            return 1e10.
        }
        return lamb:burnVec:mag.
    }

    for i in range(lowI, highI) {
        // for j in range (lowJ, highJ) {
            local startTime to guessT + i * di.
            local flightDuration to guessDur.// + j * dj.
            // print "Duration " + round(flightDuration * sToHours, 2).
            local arg to optimizeBroydenDiffs(f@,
                v(startTime, flightDuration, 0), 1, 1e-6).
            local results to lambertIntercept(
                obtable1, obtable2, arg:x, arg:y).
            if results:ok {
                set results:totalV to results:burnVec:mag
                    + 0.8 * results:matchVec:mag.
                // print "(" + i + ", " + j + ") "
                //     + round(results:burnVec:mag) + " -> "
                //     + round(results:matchVec:mag).
                if results:totalV < best:totalV {
                    set results:start to startTime.
                    set results:when to startTime - time.
                    set results:duration to flightDuration.
                    set results:arrivalTime to startTime + flightDuration.
                    set best to results.
                }
            }
        // }
    }

    return best.
}

function testLDoubleOptimize {
    local begin to time.
    local hi to hohmannIntercept(kerbin:obt, dres:obt).

    local results to lex(
        "dur", hi:duration
    ).

    local function f {
        parameter start.
        local function fDur {
            parameter dur.
            local lamb to lambertIntercept(kerbin, dres, start, dur).
            return lamb:burnVec:mag.
        }
        local function fDAndSDur {
            parameter x.
            return funcFirstSecondDeriv(fDur@, x, 1).
        }
        local bestDuration to optimizeNewtonSolve(fDAndSDur@, results:dur, 1e-6).
        set results:dur to bestDuration.
        local bestLambDur to lambertIntercept(kerbin, dres, start, bestDuration).
        return bestLambDur:burnVec:mag.
    }

    local function fDAndS {
        parameter start.
        return funcFirstSecondDeriv(f@, start, 1).
    }
    local bestStart to optimizeNewtonSolve(fDAndS@, hi:start, 1e-6).
    local bestLamb to lambertIntercept(kerbin, dres, bestStart, results:dur).
    print "-- Double " + round(bestLamb:burnVec:mag)
        + " in " + round(detimestamp(time - begin)) + " --".
    print "  ++ " + timeRoundStr(bestStart - time:seconds).
    print "  ++ " + timeRoundStr(results:dur).
    return list().
}

function testL2dOptimize {
    local begin to time.
    local hi to hohmannIntercept(kerbin:obt, dres:obt).

    local function f {
        parameter x.
        local lamb to lambertIntercept(kerbin, dres, x:x, x:y).
        return lamb:burnVec:mag.
    }

    local bestX to optimizeNewton2d(f@, v(hi:start, hi:duration, 0), 1, 1e-6).
    local bestLamb to lambertIntercept(kerbin, dres, bestX:x, bestX:y).
    print "-- N2d " + round(bestLamb:burnVec:mag)
        + " in " + round(detimestamp(time - begin)) + " --".
    print "  ++ " + timeRoundStr(bestLamb:start - time:seconds).
    print "  ++ " + timeRoundStr(bestLamb:duration).
    return list().
}

function testLCoordOptimize {
    local begin to time.
    local hi to hohmannIntercept(kerbin:obt, dres:obt).

    local function fDur {
        parameter start, x.
        local lamb to lambertIntercept(kerbin, dres, start, x).
        return lamb:burnVec:mag.
    }
    local function fStart {
        parameter dur, x.
        local lamb to lambertIntercept(kerbin, dres, x, dur).
        return lamb:burnVec:mag.
    }
    local function fDAndS {
        parameter f, x.
        return funcFirstSecondDeriv(f@, x, 1).
    }

    local dur to optimizeNewtonSolve(fDAndS@:bind(fDur@:bind(hi:start)),
        hi:duration).
    local start to optimizeNewtonSolve(fDAndS@:bind(fStart@:bind(dur)),
        hi:start).
    set dur to optimizeNewtonSolve(fDAndS@:bind(fDur@:bind(start)), dur).

    local bestLamb to lambertIntercept(kerbin, dres, start, dur).
    print "-- Coord " + round(bestLamb:burnVec:mag)
        + " in " + round(detimestamp(time - begin)) + " --".
    return list().
    
}

function testLGridNR {
    local begin to time.

    local hi to hohmannIntercept(kerbin:obt, dres:obt).

    local bestLamb to interceptGridNR(kerbin, dres, hi:start, hi:duration,
        hi:relPeriod / 10, hi:duration / 10).
    print "-- GridN2d " + round(bestLamb:burnVec:mag)
        + " in " + round(detimestamp(time - begin)) + " --".
    print "  ++ " + timeRoundStr(bestLamb:start - time:seconds).
    print "  ++ " + timeRoundStr(bestLamb:duration).
    return list().
}
