@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

function nodeExecute {
    wait 0.
    local nd to nextnode.
    print "Node in: " + round(nd:eta) 
        + ", DeltaV: " + round(nd:deltav:mag).
    local dv to nd:deltav:mag.
    
    if dv < 0.1 {
        remove nd.
        wait 1.
        return.
    }

    local rocketEstimate to shipTimeToDV(dv).

    local warpTime to nd:eta - rocketEstimate / 2 - 60.
    waitWarp(time:seconds + warpTime).
    local done to false.
    local nodeDv0 to nd:deltav.
    lock steering to nd:deltav.
    until vang(nodeDv0, ship:facing:vector) < 3 { wait 0. }
    set kuniverse:timewarp:rate to 5.
    wait until nd:eta <= rocketEstimate / 2 + 3.
    kuniverse:timewarp:cancelwarp().
    wait until nd:eta <= rocketEstimate / 2.

    until done {
        local maxAcceleration to ship:maxthrust/ship:mass.
        local minTime to 0.1. 
        if maxAcceleration > 0 {
            lock throttle to min(nd:deltav:mag / maxAcceleration, 1).
            if nd:deltav:mag / maxAcceleration < minTime {
                set done to true.
            }
        } 
        
        if nd:deltav:mag < 0.05 or vdot(nodeDv0, nd:deltav) < 0 {
            set done to true.
        }

        nodeStage().
        wait 0.
    }

    lock throttle to 0.
    wait 0.1.
    unlock steering.
    unlock throttle.
    remove nd.
    wait 1.
}

function nodeStage {
    declare local shouldStage to maxThrust = 0 and stage:ready
        and stage:number > 0.

    if shouldStage {
        print "Staging " + stage:number.
        stage.
    }
}
        
