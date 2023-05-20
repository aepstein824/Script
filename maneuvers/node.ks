@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

function nodeExecute {
    wait 0.
    local nd to nextnode.
    print " Node in: " + round(nd:eta) 
        + ", DeltaV: " + round(nd:deltav:mag).
    local dv to nd:deltav:mag.
    
    if dv < 0.1 {
        print " Removing small node with dv " + dv.
        remove nd.
        wait 1.
        return.
    }

    local steer to facing.
    local throt to 0.
    lock steering to steer.
    lock throttle to throt.

    local halfBurn to shipTimeToDV(dv / 2).

    local warpTime to nd:eta - halfBurn - 60.
    waitWarp(time:seconds + warpTime).
    local done to false.
    local nodeDv0 to nd:deltav.
    set steer to nd:deltav.
    until vang(nodeDv0, ship:facing:vector) < 3 { wait 0. }
    if nd:eta > halfBurn + 2 * kWarpCancelDur {
        set kuniverse:timewarp:rate to 5.
    }
    wait until nd:eta <= halfBurn + kWarpCancelDur.
    kuniverse:timewarp:cancelwarp().
    wait until nd:eta <= halfBurn.

    until done {
        local maxAcceleration to ship:maxthrust / ship:mass.
        local minTime to 0.05. 
        local minThrot to 0.05.
        if maxAcceleration > 0 {
            set throt to min(nd:deltav:mag / maxAcceleration, 1).
            if nd:deltav:mag < maxAcceleration * minTime * minThrot {
                // Too small for this engine
                set done to true.
            }
        } 
        
        if nd:deltav:mag < 0.05 or vdot(nodeDv0, nd:deltav) < 0 {
            // Reversed direction or just too small
            set done to true.
        }

        nodeStage().
        wait 0.04.
    }

    set throt to 0.
    wait 0.1.

    unlock steering.
    unlock throttle.
    remove nd.
    wait 1.
    clearVecDraws().
}

function nodeStage {
    local shouldStage to maxThrust = 0 and stage:ready and stage:number > 0.

    if shouldStage {
        local hasFlamedOut to false.
        local allEngines to list().
        list engines in allEngines.
        for e in allEngines {
            if e:ignition and e:flameout {
                set hasFlamedOut to true.
                break.
            }
        }
        if hasFlamedOut {
            print "Staging " + stage:number.
            stage.
        }
    }
}
        
