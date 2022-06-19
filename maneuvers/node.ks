@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").

function nodeExecute {
    wait 0.
    local nd to nextnode.
    print "Node in: " + round(nd:eta) 
        + ", DeltaV: " + round(nd:deltav:mag).
    local dv to nd:deltav:mag.


    local flowIsp to getFlowIsp().
    local flow to flowIsp[0].
    local ve to flowIsp[1] * 9.81.
    local burnRatio to constant:e ^ (-1 * dv / ve).
    local rocketEstimate to (1 - burnRatio)  * ship:mass / flow.

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
        local minS to .1 * .05.
        if maxAcceleration > 0 {
            lock throttle to min(nd:deltav:mag / maxAcceleration, 1).
            if nd:deltav:mag / maxAcceleration < minS {
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
    wait 0.1.
}

function nodeStage {
    declare local shouldStage to maxThrust = 0 and stage:ready
        and stage:number > 0.

    if shouldStage {
        print "Staging " + stage:number.
        stage.
    }
}
        
function getFlowIsp {
    local totalFuelFlow to 0.
    local totalIsp to 0.
    local engineList to List().
    list engines in engineList.
    for engine in engineList {
        if engine:ignition {
            local massFlow to 0.
            for r in engine:consumedResources:values {
                set massFlow to massFlow 
                    + r:maxfuelflow * r:density.
            }
            set totalFuelFlow to totalFuelFlow + massFlow.
            set totalIsp to totalIsp + engine:isp * massFlow.
        }
    }
    return List(totalFuelFlow, totalIsp / totalFuelFlow).
}

