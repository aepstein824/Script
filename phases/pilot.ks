@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/flight.ks").
runOncePath("0:maneuvers/hover.ks").

clearAll().
// pilotHover().
pilotFlight().

function setTarget {
    parameter params.
    if hasTarget {
        set params:tgt to target:geoposition.
    } else {
        set params:tgt to geoPosition.
        for w in allWaypoints() {
            if w:isselected {
                set params:tgt to w:geoposition.
            }
        }
    }
}

function pilotHover {
    sas off.

    local params to hoverParams.

    setTarget(params).
    set params:mode to kHover:Hover.
    set params:seek to false.

    lock steering to hoverSteering(params).
    lock throttle to hoverThrottle(params).

    until false {
        local timeDiff to 0.1.
        local pTrans to ship:control:pilottranslation.
        local pRot  to ship:control:pilotrotation.

        set params:altOffset to params:altOffset + 3 * pTrans:z * timeDiff.

        if pRot:y > 0.5 {
            setTarget(params).
            set params:seek to true.
        } else if pRot:y < -0.5 {
            set params:seek to false.
        }

        print params.

        wait timeDiff.
    }
}

function pilotFlight {
    stageToMax().

    steeringManager:resettodefault().
    set steeringmanager:showsteeringstats to false.
    // Setting the roll range to 180 forces roll control everywhere
    set steeringmanager:rollcontrolanglerange to 180.
    // The stop time calc doesn't work for planes
    set steeringmanager:maxstoppingtime to 100.
    // kp defaults to be 1, but we need to be sure for a hack in our steering
    set steeringmanager:yawpid:kp to 1.
    set steeringmanager:pitchpid:kp to 1.
    // we don't want to accumulate anything in level flight
    set steeringmanager:pitchpid:ki to 0.
    set steeringmanager:rollpid:ki to 0.
    set steeringmanager:yawpid:ki to 0.

    local params to flightParams.
    set params:arrow:show to false.

    lock steering to flightSteering(params).
    lock throttle to flightThrottle(params).

    if status = "FLYING" {
        flightBeginLevel(params).
    } else {
        brakes on.
    }

    until false {
        local timeDiff to 0.1.
        local pRot to ship:control:pilotrotation.
        local pTrans to ship:control:pilottranslation.

        if pRot:y < -0.5 {
            // press W
            flightBeginTakeoff(params).
        } else if pRot:y > 0.5 {
            // press S
            flightBeginLanding(params).
        } else if pRot:z < -0.5 {
            // press Q
            flightBeginLevel(params).
        } else if pRot:z > 0.5 {
            // press E
            flightResetSpds(params, params:cruiseV).
        }

        set params:xacc to params:xacc + 2.5 * pTrans:x * timeDiff.
        if abs(pTrans:x) > 0.01 {
            print "xacc: " + params:xacc.
        }
        set params:vspd to params:vspd + .5 * pTrans:y * timeDiff.
        if abs(pTrans:y) > 0.01 {
            print "vspd: " + params:vspd.
        }
        set params:hspd to params:hspd + 5 * pTrans:z * timeDiff.
        if abs(pTrans:z) > 0.01 {
            print "hspd: " + params:hspd.
        }

        // print steeringmanager:yawpid:setpoint
            // + ", " + steeringManager:yawpid:input * constant:radtodeg.


        flightIter(params).
        // printPids().
        wait 0.1.
    }

}