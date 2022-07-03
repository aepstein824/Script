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
    local distance to ((target:position - ship:position):mag 
        - kRndvParams:floatDist).
    local accel to ship:maxthrust / ship:mass.
    print "Accel " + accel.
    local shortestHalf to sqrt(distance / accel).
    print "Shortest half " + shortestHalf.
    local maxAccel to 0.5. // accel for 1/4 total
    local maxSpeed to min(accel * shortestHalf * maxAccel,
        kRndvParams:maxSpeed). 
    print "Max Speed " + maxSpeed.

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
        local thrust to invLerp(2 * goalV:mag, 0, ship:maxThrust).
        if thrust < 0.01 {
            set thrust to 0.
        }
        return thrust.
    }

    lock steering to toGoalV(1).
    lock throttle to goalThrot(1).

    local reverseDist to 2 * shipTimeToDV(maxSpeed) * maxSpeed 
        + kRndvParams:floatDist.
    wait until (target:position - ship:position):mag < reverseDist.

    lock steering to toGoalV(.1).
    lock throttle to goalThrot(.1).
    wait until (target:position - ship:position):mag < kRndvParams:floatDist.

    lock steering to toGoalV(0).
    lock throttle to goalThrot(0).
    wait until toGoalV(0):mag < 1.

    lock throttle to 0.
    lock steering to ship:position - target:position.
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
    lock throttle to 0.
    lock steering to target:position - ship:position.
    wait 3.

    local ourPort to ship:dockingports[0].
    local tgtPort to target:dockingports[0].
    
    ourport:getmodule("ModuleDockingNode"):doevent("Control From Here").

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
        local towards to tgtPort:position - ourPort:position.
        local tr to target:velocity:orbit - ship:velocity:orbit.

        local desired to 0.5 * towards:normalized.
        local delta to desired + tr.
        if towards:mag < 2 {
            break.
        }
        setRcs(delta).
    }
    rcs off.
} 
