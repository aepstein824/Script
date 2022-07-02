@LAZYGLOBAL OFF.

runOncePath("0:common/operations.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").

declare global kLandAtm to lexicon().

set kLandAtm:EntryPe to 45000.
set kLandAtm:BurnAlt to 55000.
set kLandAtm:ReturnTanly to 130.
set kLandAtm:Winged to true.
set kLandAtm:Coast to true.
set kLandAtm:SurrenderQ to .05.
set kLandAtm:CoastReserve to 100.
set kLandAtm:CoastH to 50.
set kLandAtm:CoastSpd to 5.
set kLandAtm:Roll to 0.

function landFromDeorbit {
    lock throttle to 0.
    unlock steering.

    getToAtm().

    if kLandAtm:Winged { 
        print "Winged Descent".
        wingedDescent().
    } else {
        print "Burning Fuel".
        burnExtraFuel().
    }

    kuniverse:timewarp:cancelwarp().

    wait until ship:q > kLandAtm:SurrenderQ.
    print "Surrender and Slow".
    
    lock throttle to 0.
    unlock steering.
    brakes on.
    chutes on.
    stageTo(0).
    set kuniverse:timewarp:rate to 2.

    wait until groundAlt() < kLandAtm:CoastH.
    print "Coasting to the ground.".

    kuniverse:timewarp:cancelwarp().
    gear on.
    if (kLandAtm:Coast) {
        brakes off.
        coast(kLandAtm:CoastSpd).
    }

}

function getToAtm {
    if ship:altitude > 70000 {
        set kuniverse:timewarp:mode to "RAILS".
        set kuniverse:timewarp:rate to 100.
    }
    wait until ship:altitude < 70000.
    kuniverse:timewarp:cancelwarp().
    wait 5.
    set kuniverse:timewarp:mode to "PHYSICS".
}

function wingedDescent {
    lock throttle to 0.
    lock steering to heading(90, 20, kLandAtm:Roll).
}

function burnExtraFuel {
    lock steering to ship:srfretrograde.
    
    wait until ship:altitude < kLandAtm:BurnAlt.
    lock throttle to 0.5.
    until ship:deltav:current < kLandAtm:CoastReserve or stage:number = 0 {
        shipStage().
        wait 0.
    }

}

function planLandingBurn {
    local sNorm to shipNorm().

    local ksc to waypoint("ksc").

    // doesn't work, need to account for eccentricity and spin
    local orbW to removeComp(ksc:position - body:position, sNorm).
    local pePos to shipPAtPe().
    local wTanly to vectorAngleAround(pePos, sNorm, orbW).
    local burnTanly to mod(wTanly - kLandAtm:ReturnTanly + 360, 360).
    local burnTime to timeBetweenTanlies(obt:trueanomaly, burnTanly, obt) + time.
    local burnPos to shipPAt(burnTime).
    local rb to burnPos:mag.
    local rp to body:radius + kLandAtm:EntryPe.
    local vb to sqrt(2 * ship:body:mu * rp / rb / (rp + rb)).
    local burnStart to removeComp(shipVAt(burnTime), burnPos).
    local burnMag to vb - burnStart:mag.
    add node(burnTime, 0, 0, burnMag).
}