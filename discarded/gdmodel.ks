@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

function gdmodelCreate {
    parameter modelFunc, modelGrad.
    return lexicon(
        "func", modelFunc,
        "grad", modelGrad
    ).
}

function gdmodelGradMag {
    parameter grad.
    local sum to 0.
    for v in grad:values {
        set sum to sum + v ^ 2.
    }
    return sqrt(sum).
}

function gdmodelUpdate {
    parameter m, w, yTgt, x, lr to 1.
    return gdmodelBacktracking(m, w, yTgt, x, lr).
}

function gdmodelBacktracking {
    parameter m, w, yTgt, x, lr to 1.

    local gamma to 0.5.
    local t to 1.
    local c to 0.01.
    local yModel to m:func(w, x).
    local mGrad to m:grad(w, x).
    local gradMag to gdmodelGradMag(mGrad).
    local initLoss to (yTgt - yModel) ^ 2.
    local wOut to lexicon().

    for i in range(20) {
        local mseCoeff to clamp(2 * (yTgt - yModel), -lr, lr) * t.
        for k in w:keys {
            local msePartial to mseCoeff * mGrad[k].
            set wOut[k] to w[k] + msePartial.
        }

        local newLoss to (yTgt - m:func(wOut, x)) ^ 2.
        // print "I[" + round(initLoss, 2) + "] - N["
        //     + round(newLoss, 2) + "] = " 
        //     + (initLoss - newLoss) + " > "
        //     + (lr * mseCoeff * gradMag).
        if initLoss - newLoss > (c * mseCoeff * gradMag) {
            // print "Success! " + i.
            return wOut.
        }
        set t to t * gamma.
    }
    // print "Failure".
    return w.
}

function gdmodelClampGD {
    parameter m, w, yTgt, x, lr to 1.

    local yModel to m:func(w, x).
    local grad to m:grad(w, x).

    local learn to lr * 2 * clamp((yTgt - yModel), -1, 1).

    local wOut to lexicon().
    for k in w:keys {
        set wOut[k] to w[k] + learn * clamp(grad[k], -1, 1).
    }

    return wOut.
}

function gdmodelQuadFunc {
    parameter w, x.
    return w:a * x ^ 2 + w:b * x + w:c.
}

function gdmodelQuadGrad {
    parameter w, x.

    return lexicon(
        "a", x ^ 2,
        "b", x,
        "c", 1
    ).
}

function gdmodelQuad {
    return gdmodelCreate(gdmodelQuadFunc@, gdmodelQuadGrad@).
}

// Using in flight data to train a model of lift = f(aoa) did not work. The
//  model would converge on a local maxima without even the correct local
//  gradient. It would get close enough that in level flight, the magnitude
//  of the gradient was too small to be meaningful. This is no better than
//  learning a single aoa for trim, which might be more effective than I'm
//  willing to admit.
// function flightModelUpdate {
//     parameter params.

//     if status = "LANDED" {
//         return.
//     }

//     local pro to lookDirUp(velocity:surface, facing:upvector).
//     local aoa to vectorAngleAround(pro:vector, facing:rightvector,
//         facing:vector).
//     if aoa > 180 { set aoa to aoa - 360. }
//     local aero to far:aeroforce.
//     local v2 to velocity:surface:mag.
//     local lift to vdot(pro:upvector, aero) / v2.
//     local drag to vdot(pro:vector, aero) / v2.
//     local mlift to params:flightModel:func(params:liftWeights, aoa).
//     local mdrag to params:flightModel:func(params:dragWeights, aoa).
//     print "AoA " + aoa + ", lift " + round(mlift / lift, 4) 
//         + ", drag " + round(mdrag / drag, 4) at(0, 0).
//     local lw to params:liftWeights.
//     local lowZero to quadraticFormula(lw:a, lw:b, lw:c, -1 * sgn(lw:a)).
//     local hiZero to quadraticFormula(lw:a, lw:b, lw:c, 1 * sgn(lw:a)).
//     local maxAng to (lowZero + hiZero) / 2.
//     print "Lift angles " + round(lowZero, 2) + ", " + round(hiZero, 2) + "      " at (0, 1).
//     print "lw " + lw at(0, 2).
//     print "lift " + lift at (0, 3).
//     set params:liftWeights to modelUpdate(params:flightModel, params:liftWeights, lift, aoa, 0.01).
//     set params:dragWeights to modelUpdate(params:flightModel, params:dragWeights, drag, aoa, 0.01).
//     local g to gat(altitude) * ship:mass / v2.
//     local stable to quadraticFormula(lw:a, lw:b,
//         lw:c - g, -1 * sgn(lw:a)).
//     print "stable angle " + stable at (0, 4).
//     print "g " + g at(0,5).
//     set params:modelAoA to stable + vectorAngleAround(params:level:vector, params:level:rightvector, pro:vector).
//  }