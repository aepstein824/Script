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
    set steeringmanager:yawpid:ki to 0.
    set steeringmanager:pitchpid:ki to 0.
    set steeringmanager:rollpid:ki to 0.

    local params to flightParams.
    // set params:arrow:show to true.

    lock steering to flightSteering(params).
    lock throttle to flightThrottle(params).

    until false {
        local pRot to ship:control:pilotrotation.

        if pRot:y < -0.5 {
            flightBeginTakeoff(params).
        } else if pRot:y > 0.5 {
            flightBeginLevel(params).
        }

        flightIter(params).
        wait 0.1.
    }

}