@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:common/control.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/math.ks").

global kRndvParams to Lexicon().
set kRndvParams:floatDist to 200.
set kRndvParams:maxSpeed to 50.
set kRndvParams:thrustAng to 5.
set kRndvParams:rcsSlowDist to 150.
set kRndvParams:rcsKp to 2.

function planIntercept {
    local best to Lexicon().
    set best:burnVec to V(10000,0,0).
    for i in range(1, 15) {
        for j in list(6, 8, 10) {
            local startTime to time + i * 2 * 60.
            local flightDuration to j * 60.
            local results to lambert(ship, target, startTime, 
                flightDuration, false).

            if results["ok"] {
                print "Found orbit with dV " + results:burnVec:mag.
                if results:burnVec:mag < best:burnVec:mag {
                    set best to results.
                }
            }
        }
    }
    if best:haskey("burnNode") {
        local nd to best:burnNode.
        add nd.
    }
}

function ballistic {
    print "Ballistic rndv with " + target:name.
    local function distance {
        return (target:position - ship:position):mag.
    }
    local floatDist to kRndvParams:floatDist.
    local currentSpeed to (target:velocity:orbit - ship:velocity:orbit):mag.
    local switchDist to floatDist.
    local endSpd to 5.
    local maxSpeed to endSpd.
    local burnDist to 0.
    if distance() > floatDist {
        local maxAccel to 0.5. // accel for 1/4 total
        local shortestHalftime to sqrt((distance() - floatDist) / shipAccel()).
        local infFuelSpd to shipAccel() * shortestHalftime * maxAccel.
        print " Infinite Fuel Speed " + round(infFuelSpd).
        set maxSpeed to min(ship:deltav:current / 3, 
            min(infFuelSpd, max(kRndvParams:maxSpeed,
            currentSpeed))). 
        print " Max Speed " + round(maxSpeed).
        local burnTime to 1.3 * shipTimeToDV(maxSpeed) + 5.
        set burnDist to 0.5 * maxSpeed * burnTime.
        print " Slow dist " + burnDist.
        set switchDist to 2 * burnDist. 
    }

    local respond to true.
    local stageTowards to true.

    controlLock().
    enableRcs().
    until false {
        local towards to target:position - ship:position.
        local dist to towards:mag.

        local shortDist to dist - 2 * floatDist.
        local desiredSpd to rndvSpd(shortDist, burnDist, maxSpeed, endSpd).
        local relV to velocity:orbit - target:velocity:orbit.
        local relTowards to vdot(relV, towards:normalized).

        if stageTowards {
            // while far, push velocity towards the target
            local desired to desiredSpd * towards:normalized.
            local delta to desired - relV.
            local angFactor to 1.
            local angle to vang(facing:vector, delta).
            if angle > kRndvParams:thrustAng {
                set angFactor to 1 - invLerp(angle, 0,
                    2 * kRndvParams:thrustAng).
            }
            local magFactor to invLerp(5 * delta:mag, 0, shipAccel()).
            local thrust to angFactor * magFactor.

            if delta:mag < 0.1 and respond {
                set respond to false.
            }
            if delta:mag > 0.3 and not respond or distance < (floatDist * 3) {
                set respond to true.
            }
            set controlSteer to delta.
            if respond {
                set controlThrot to thrust.
            } else {
                set controlThrot to 0.
            }
            if shortDist < switchDist {
                set stageTowards to false.
            }
        } else {
            // while close, only burn retrograde
            local steer to -relV.
            if shortDist < 0 {
                set desiredSpd to 0.
            }

            if vang(relV, towards) > 20 {
                set controlThrot to 1.
            } else {
                local magError to relV:mag - desiredSpd.
                // if desiredSpd is greater, throt will be 0
                local magFactor to invLerp(5 * magError, 0, shipAccel()).
                set controlThrot to magFactor.
            }

            if vang(steer, facing:vector) > kRndvParams:thrustAng {
                set controlThrot to 0.
            }
            set controlSteer to steer.
            local sideV to vxcl(towards, relV):mag.
            if relV:mag < endSpd and relTowards > -1 and sideV < 1 {
                break.
            }
        }

        wait 0.
    }
    disableRcs().
    controlUnlock().
}

function rcsNeutralize {
    print "Neutralize relative velocity with RCS".
    lock throttle to 0.
    lock steering to "kill".

    local rcsInvThrust to shipRcsInvThrust().

    enableRcs().
    until false {
        local tr to target:velocity:orbit - ship:velocity:orbit.
        if (tr:mag < 0.3){
            break.
        }
        shipRcsDoThrust(tr, rcsInvThrust).
        wait 0.
    }
    disableRcs().
}

function rcsApproach {
    print "RCS Approach".

    legs off.
    local ports to opsPortFindPair(target).
    local ourPort to ports[0].
    local tgtPort to ports[1].
    opsControlFromPort(ourPort).

    enableRcs().
    lock steering to tgtPort:position - ourPort:position.
    lock throttle to 0.
    wait 3. 

    local rcsThrust to shipRcsGetThrust().
    local rcsInvThrust to vecInvertComps(rcsThrust).

    local slowDist to kRndvParams:rcsSlowDist.
    local maxDist to min(slowDist,
        (tgtPort:position - ourPort:position):mag).
    local rcsAcc to rcsThrust:z / ship:mass / 2.
    local rcsMaxSpd to sqrt(maxDist * rcsAcc).
    local rcsSpdFunc to {
        parameter dist.
        return rndvSpd(dist, slowDist, rcsMaxSpd, 0.2).
    }.
    local kp to kRndvParams:rcsKp.

    local startProcCount to procCount().
    until false {
        local towards to tgtPort:position - ourPort:position.
        local dist to towards:mag.

        if dist < 1.1 or procCount() <> startProcCount {
            break.
        }

        local spdAndAcc to funcAndDeriv(rcsSpdFunc, dist).
        local desiredSpd to spdAndAcc[0].
        local desiredAcc to spdAndAcc[1] * desiredSpd.

        local desiredV to desiredSpd * towards:normalized.
        local accV to desiredAcc * towards:normalized.
        local relV to ship:velocity:orbit - target:velocity:orbit.
        local delta to kp * (desiredV - relV).
        // print "dist " + round(dist, 1)
        //     + "  |  desired " + vecround(facing:inverse * desiredV, 2)
        //     + "  |  delta " + vecround(facing:inverse * delta, 2).

        shipRcsDoThrust(delta + accV, rcsInvThrust).

        wait 0.
    }
    print " Drifting toward target".

    disableRcs().
    controlUnlock().
}

function rndvSpd {
    parameter dist, slowDist, maxSpd, minSpd.
    if dist < 3 {
        return minSpd.
    }
    if dist < 0 {
        return 0.
    }
    local curve to 1.
    if dist < slowDist {
        set curve to sqrt(invLerp(dist - 3, 0, slowDist)).
    }
    local clamped to lerp(curve, minSpd, maxSpd).
    return clamped.
}

function doubleBallistic {
    ballistic().
    if (target:position:mag > (kRndvParams:floatDist + 50)) {
        ballistic().
    }
}