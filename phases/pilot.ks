@LAZYGLOBAL OFF.

runOncePath("0:common/info.ks").
runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/hover.ks").

pilotHover().

function pilotHover {
    sas off.

    local params to hoverParams.

    if hasTarget {
        set params:tgt to target:geoposition.
    } else {
        set params:tgt to geoPosition.
    }
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
            set params:tgt to target:geoPosition.
            set params:seek to true.
        } else if pRot:y < -0.5 {
            set params:seek to false.
        }

        print params.

        wait timeDiff.
    }
}