@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

function nodeExecute {
    parameter useRcs to false.

    local rcsThrusters to list().
    list rcs in rcsThrusters.
    set useRcs to  useRcs and not rcsThrusters:empty().
    

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
        local minTime to 0.05 * 0.05. 
        if maxAcceleration > 0 {
            lock throttle to min(nd:deltav:mag / maxAcceleration, 1).
            if nd:deltav:mag / maxAcceleration < minTime {
                // Too small for this engine
                set done to true.
            }
        } 
        
        if nd:deltav:mag < 0.05 or vdot(nodeDv0, nd:deltav) < 0 {
            // Reversed direction or just too small
            set done to true.
        }

        if useRcs and nd:deltav:mag < 0.5 {
            // Leave the last bit for rcs if in use
            set done to true.
        }

        nodeStage().
        wait 0.04.
    }

    lock throttle to 0.
    wait 0.1.

    if useRcs {
        enableRcs().
        until nd:deltav:mag < 0.05 {
            setRcs(nd:deltav).
            wait 0.
        }
        setRcs(v(0,0,0)).
        disableRcs().
    }
    unlock steering.
    unlock throttle.
    remove nd.
    wait 1.
    clearVecDraws().
}

function nodeRcs {
    nodeExecute(true).
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
        
function setRcs {
    parameter vt.
    if vt:mag > 0 and vt:mag < 0.2 {
        set vt to vt * 0.2 / vt:mag.
    }
    set ship:control:translation to v(
        vDot(vt, ship:facing:starvector),
        vDot(vt, ship:facing:topvector),
        vDot(vt, ship:facing:forevector)
    ).
}