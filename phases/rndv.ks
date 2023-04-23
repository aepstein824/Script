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
set kRndvParams:rcsSpd to 5.
set kRndvParams:rcsSlowDist to 150.


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
        set maxSpeed to min(infFuelSpd, max(kRndvParams:maxSpeed,
            currentSpeed)). 
        print " Max Speed " + round(maxSpeed).
        local burnTime to 1.3 * shipTimeToDV(maxSpeed) + 5.
        set burnDist to 0.5 * maxSpeed * burnTime.
        print " Slow dist " + burnDist.
        set switchDist to 2 * burnDist. 
    }

    local respond to true.

    controlLock().
    enableRcs().
    until false {
        local towards to target:position - ship:position.
        local dist to towards:mag.

        local shortDist to dist - 2 * floatDist.
        local desiredSpd to rndvSpd(shortDist, burnDist, maxSpeed, endSpd).
        local relV to velocity:orbit - target:velocity:orbit.
        local relTowards to vdot(relV, towards:normalized).
        local movingAway to relTowards < 0.

        if shortDist > switchDist or movingAway {
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
        } else {
            // while close, only burn retrograde
            local steer to -relV.
            if movingAway or shortDist < 0 {
                set desiredSpd to 0.
            }
            if vang(steer, facing:vector) < kRndvParams:thrustAng {
                local magError to relV:mag - desiredSpd.
                // if desiredSpd is greater, throt will be 0
                local magFactor to invLerp(5 * magError, 0, shipAccel()).
                set controlThrot to magFactor.
            } else {
                set controlThrot to 0.
            }
            set controlSteer to steer.
            local sideV to vxcl(towards, relV):mag.
            if relV:mag < endSpd and relTowards > -1 and sideV < 1 {
                break.
            }
        }

        // if dist > 10 * burnDist {
        //     set kuniverse:timewarp:mode to "PHYSICS".
        //     set kuniverse:timewarp:rate to 4.
        // } else {
        //     set kuniverse:timewarp:rate to 1.
        // }
    
        wait 0.
    }
    disableRcs().
    controlUnlock().
}

function rcsNeutralize {
    print "Neutralize relative velocity with RCS".
    lock throttle to 0.
    lock steering to "kill".

    enableRcs().
    until false {
        local tr to target:velocity:orbit - ship:velocity:orbit.
        if (tr:mag < 0.3){
            break.
        }
        shipFacingRcs(tr).
        wait 0.
    }
    disableRcs().
}

function rcsApproach {
    print "RCS Approach".

    legs off.
    local ourPort to getPort(ship).
    opsControlFromPort(ourPort).
    local tgtPort to getPort(target).

    enableRcs().
    lock steering to tgtPort:position - ship:position.
    lock throttle to 0.
    wait 3. 

    until false {
        local towards to tgtPort:position - ourPort:position.
        local dist to towards:mag.

        if dist < 1.1 {
            break.
        }

        local slowDist to kRndvParams:rcsSlowDist.
        local desiredSpd to rndvSpd(dist, slowDist, kRndvParams:rcsSpd, 0.4).
        local desired to desiredSpd * towards:normalized.
        local relV to ship:velocity:orbit - target:velocity:orbit.
        // print "desired " + facing:inverse * desired.
        // print "relV " + facing:inverse * relV.
        local delta to desired - relV.

        local urgency to lerp(1 - (dist / slowDist), 1, 5).
        set delta to delta * urgency.

        shipFacingRcs(delta).
        wait 0.
    }

    disableRcs().
    controlUnlock().
}

function rndvSpd {
    parameter dist, slowDist, maxSpd, minSpd.
    if dist < 2 {
        return minSpd.
    }
    if dist < 0 {
        return 0.
    }
    local curve to 1.
    if dist < slowDist {
        set curve to sqrt(invLerp(dist - 2, 0, slowDist)).
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