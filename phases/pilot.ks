@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/flight.ks").
runOncePath("0:maneuvers/hover.ks").


pilotHybrid().

function pilotHybrid {
    local flyNext to status = "FLYING"
        or vang(facing:forevector, up:forevector) > 30.

    until false {
        if flyNext {
            clearAll().
            pilotFlight().
            set flyNext to false.
            clearAll().
            print "Switching to Hover".
            hoverFlightToHover().
        } else {
            clearAll().
            pilotHover().
            set flyNext to true.
            hoverHoverToFlight().
        }
    }
}

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
    stageToMax().

    local params to hoverDefaultParams().

    setTarget(params).
    set params:mode to kHover:Hover.
    set params:seek to false.

    lock steering to hoverSteering(params).
    lock throttle to hoverThrottle(params).

    until false {
        local timeDiff to 0.1.
        local pTrans to ship:control:pilottranslation.
        local pRot  to ship:control:pilotrotation.

        set params:vspdCtrl to params:vspdCtrl + 3 * pTrans:z * timeDiff.

        if pRot:y > 0.5 {
            // press S
            setTarget(params).
            set params:seek to true.
        } else if pRot:y < -0.5 {
            // press W
            set params:seek to false.
        } else if pRot:z < -0.5 {
            // press Q
            set params:mode to kHover:Vspd.
        } else if pRot:x < -0.5 {
            // press A
            set params:mode to kHover:Hover.
        } else if pRot:z > 0.5 {
            // press E
            set params:mode to kHover:Stop.
        } else if pRot:x > 0.5 {
            // press D
            return.
        }

        // print params.
        hoverIter(params).
        wait timeDiff.
    }
}

function pilotFlight {
    stageToMax().

    flightSetSteeringManager().

    local params to flightDefaultParams().
    // set params:arrow:show to false.
    flightCreateReport(params).

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
            print "Takeoff".
        } else if pRot:y > 0.5 {
            // press S
            flightBeginLanding(params).
            print "Landing".
        } else if pRot:z < -0.5 {
            // press Q
            flightBeginLevel(params).
            print "Level".
        } else if pRot:z > 0.5 {
            // press E
            flightResetSpds(params, params:cruiseV).
            print "Reset Spds".
        } else if pRot:x > 0.5 {
            // press D
            return.
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