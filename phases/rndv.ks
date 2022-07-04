@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/math.ks").



global kRndvParams to Lexicon().
set kRndvParams:floatDist to 200.
set kRndvParams:maxSpeed to 100.
set kRndvParams:thrustAng to 5.
set kRndvParams:rcsSpd to 5.

clearscreen.

// function rndvWithTarget {
//     local ourBodies to list(body).
//     local bodyIter to body.
//     until bodyIter = sun {
//         bodyIter:add(bodyIter).
//         set bodyIter to bodyIter:obt:body.
//     }

//     local tgtBodyIter to target:obt:body.
//     until false {
//         local idx to ourBodies:find(tgtBodyIter).
//     }
// }
//planIntercept().
// nodeExecute().
// catchInCircle().
// ballistic().


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

function catchInCircle {
    local vChange to 5.
    if vdot(target:position, ship:prograde:vector) > 0 {
       // go slower, fall into a faster orbit, catch up 
       set vChange to -1 * vChange.
    }
    add node(time + 60, 0, 0, vChange).
    nodeExecute().
    function planetAngle {
        return abs(vectorAngleAround(-1 * body:position,
            vCrs(ship:prograde:vector, -1 * body:position),
            target:position - body:position)).
    }
    set kuniverse:timewarp:rate to 50.
    wait until planetAngle() < 3.
    kuniverse:timewarp:cancelwarp().
}

function ballistic {
    print "Ballistic rndv with " + target:name.
    local function distance {
        return (target:position - ship:position):mag.
    }
    local floatDist to kRndvParams:floatDist.
    local currentSpeed to (target:velocity:orbit - ship:velocity:orbit):mag.
    local shortestHalftime to sqrt((distance() - floatDist) / shipAccel()).
    local maxAccel to 0.5. // accel for 1/4 total
    local infFuelSpd to shipAccel() * shortestHalftime * maxAccel.
    print " Infinite Fuel Speed " + round(infFuelSpd).
    local maxSpeed to min(infFuelSpd, max(kRndvParams:maxSpeed, currentSpeed)). 
    print " Max Speed " + round(maxSpeed).

    local function toGoalV{
        parameter approach.
        local retro to target:velocity:orbit.
        local toward to (target:position - ship:position):normalized.
        local closeIn to approach * maxSpeed * toward.
        //print  (retro + closeIn - ship:velocity:orbit).
        return (retro + closeIn - ship:velocity:orbit).
    }

    local function goalThrot {
        parameter approach.
        local goalV to toGoalV(approach).
        if vang(ship:facing:vector, goalV) > kRndvParams:thrustAng {
            return 0.
        }
        local thrust to invLerp(5 * goalV:mag, 0, shipAccel()).
        if thrust < 0.01 {
            set thrust to 0.
        }
        return thrust.
    }

    local function timeToBurn {
        parameter dv.
        return 1.3 * shipTimeToDV(dv) + 5.
    }

    lock steering to toGoalV(1).
    lock throttle to goalThrot(1).

    local reverseDist to timeToBurn(maxSpeed) * maxSpeed + floatDist.
    if distance() > 10 * reverseDist {
        set kuniverse:timewarp:mode to "PHYSICS".
        set kuniverse:timewarp:rate to 4.
    }
    print " Will reverse at " + round(reverseDist) + "m".
    wait until distance() < reverseDist.
    kuniverse:timewarp:cancelwarp().

    local stopFactor to 0.1.
    local stopSpd to maxSpeed * stopFactor.
    lock steering to toGoalV(stopFactor).
    lock throttle to goalThrot(stopFactor).

    local stopDist to timeToBurn(stopSpd) * stopSpd + floatDist.
    print " Will stop at " + round(stopDist) + "m".
    wait until distance() < stopDist.

    lock steering to toGoalV(0).
    lock throttle to goalThrot(0).
    wait until toGoalV(0):mag < 1.

    lock throttle to 0.
    unlock steering.
}

function rcsNeutralize {
    lock throttle to 0.
    lock steering to ship:position - target:position.

    wait 3.

    rcs on.
    until false {
        local tr to target:velocity:orbit - ship:velocity:orbit.
        if (tr:mag < 0.1){
            break.
        }
        setRcs(tr).
        wait 0.
    }
    set ship:control:translation to v(0,0,0).
    rcs off.
}

function rcsApproach {
    local ourPort to ship:dockingports[0].
    ourPort:getmodule("ModuleDockingNode"):doevent("Control From Here").
    local tgtPort to target.
    local tgtPorts to target:dockingports.
    if not tgtPorts:empty() {
        set tgtPort to tgtPorts[0].
    }
    lock steering to tgtPort:position - ship:position.
    lock throttle to 0.
    wait 3. 

    rcs on.
    local approachStart to time.
    local halfway to (tgtPort:position - ourPort:position):mag.
    until false {
        local towards to tgtPort:position - ourPort:position.
        local tr to target:velocity:orbit - ship:velocity:orbit.

        local desired to kRndvParams:rcsSpd * towards:normalized.
        local delta to desired + tr.
        if delta:mag < 0.1 or towards:mag < halfway / 2{
            break.
        }
        setRcs(delta).
    }
    local approachDur to time - approachStart.
    local reverseDist to approachDur * kRndvParams:rcsSpd / 2 + 10.
    wait until (tgtPort:position - ourPort:position):mag < reverseDist.

    until false {
        if not hasTarget {
            break.
        }
        local towards to tgtPort:position - ourPort:position.
        local tr to target:velocity:orbit - ship:velocity:orbit.

        local desired to 0.5 * towards:normalized.
        local delta to desired + tr.
        if towards:mag < 2 {
            break.
        }
        setRcs(delta).
    }
    setRcs(v(0, 0, 0)).
    rcs off.
} 

function doubleBallisticRcs {
    ballistic().
    rcsNeutralize().
    if (target:position:mag > kRndvParams:floatDist) {
        ballistic().
        rcsNeutralize().
    }
}