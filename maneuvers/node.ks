@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:common/orbital.ks").
runOncePath("0:common/ship.ks").

function nodeExecute {
    wait 0.
    local nd to nextnode.
    local ndRnp to v(nd:radialout, nd:normal, nd:prograde).
    local dv to nd:deltav:mag.
    print " Node in: " + timeRoundStr(nd:eta) 
        + ", DeltaV: " + round(dv) + " " + vecround(ndRnp, 2).
    
    if dv < 0.1 {
        print " Removing small node with dv " + dv.
        remove nd.
        wait 1.
        return.
    }

    enableRcs().
    local throt to 0.
    lock throttle to throt.

    local halfBurn to shipTimeToDV(dv / 2).

    local warpTime to nd:eta - halfBurn - 60.
    waitWarp(time:seconds + warpTime).
    local done to false.
    local nodeDv0 to nd:deltav.
    lock steering to lookDirUp(nodeDv0, facing:upvector).
    until vang(nodeDv0, ship:facing:vector) < 3 { wait 0. }
    if nd:eta > halfBurn + 2 * kWarpCancelDur {
        set kuniverse:timewarp:rate to 5.
    }
    wait until nd:eta <= halfBurn + kWarpCancelDur.
    kuniverse:timewarp:cancelwarp().
    wait until nd:eta <= halfBurn.
    set kuniverse:timewarp:mode to "PHYSICS".
    local warped to false.
    local unWarped to false.

    until done {
        local maxAcceleration to ship:maxthrust / ship:mass.
        local remaining to nd:deltav:mag.
        local burnTime to remaining / maxAcceleration.

        if burnTime > 10 and not warped {
            set kuniverse:timewarp:rate to 4.
            set warped to true.
        }
        if burnTime <= 10 and not unWarped {
            set kuniverse:timewarp:rate to 1.
            set unWarped to true.
        }

        local minTime to 0.05. 
        local minThrot to 0.05.
        if maxAcceleration > 0 {
            set throt to min(burnTime, 1).
            if nd:deltav:mag < maxAcceleration * minTime * minThrot {
                // Too small for this engine
                set done to true.
            }
        } 
        
        if nd:deltav:mag < 0.05 or vdot(nodeDv0, nd:deltav) < 0 {
            // Reversed direction or just too small
            set done to true.
        }

        shipStage().
        wait 0.
    }

    set throt to 0.
    kuniverse:timewarp:cancelwarp().
    wait 0.1.

    unlock steering.
    unlock throttle.
    disableRcs().
    remove nd.
    wait 1.
    clearVecDraws().
}

