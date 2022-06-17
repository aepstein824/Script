@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/lambert.ks").

global kRndvParams to Lexicon().
set kRndvParams:floatDist to 200.
set kRndvParams:maxSpeed to 100.
set kRndvParams:thrustAng to 5.

//planIntercept().
// nodeExecute().
// catchInCircle().
ballistic().

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

function invLerp {
    parameter x, lower, upper.
    local diff to upper - lower.
    if diff = 0 {
        return 1.
    }
    return min((x - lower) / diff, 1).
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
        return invLerp(goalV:mag, 0, ship:maxThrust).
    }

    lock steering to toGoalV(1).
    lock throttle to goalThrot(1).

    local reverseDist to .25 * distance + kRndvParams:floatDist.
    wait until (target:position - ship:position):mag < reverseDist.

    lock steering to toGoalV(0).
    lock throttle to goalThrot(0).
    wait until toGoalV(0):mag < 2.

    lock throttle to 0.
    lock steering to ship:position - target:position.
}
