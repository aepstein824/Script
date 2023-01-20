@LAZYGLOBAL OFF.

runOncePath("0:common/operations.ks").
runOncePath("0:common/ship.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").

declare global kLandAtm to lexicon().

set kLandAtm:EntryPe to 45000.
set kLandAtm:BurnAlt to 55000.
set kLandAtm:ReturnTanly to 100.
set kLandAtm:Winged to false.
set kLandAtm:Coast to false.
set kLandAtm:SurrenderH to 20000.
set kLandAtm:CoastReserve to 120.
set kLandAtm:CoastH to 80.
set kLandAtm:CoastSpd to 5.
set kLandAtm:Roll to 0.

function landFromDeorbit {
    lock throttle to 0.
    unlock steering.

    getToAtm().
    brakes on.
    
    if kLandAtm:Winged { 
        print "Winged Descent".
        wingedDescent().
    } else {
        print "Burning Fuel".
        burnExtraFuel().
    }


    wait until altitude < kLandAtm:SurrenderH.
    print "Surrender and Slow".
    kuniverse:timewarp:cancelwarp().
    
    lock throttle to 0.
    unlock steering.
    chutes on.
    stageTo(0).

    wait until groundAlt() < kLandAtm:CoastH.
    print "Coasting to the ground.".

    gear on.
    if (kLandAtm:Coast) {
        kuniverse:timewarp:cancelwarp().
        coast(kLandAtm:CoastSpd).
    } else {
        wait until status = "LANDED" or status = "SPLASHED".
    }

    print "Landed at " + geoPosition.
}

function getToAtm {
    if ship:altitude > 70000 {
        set kuniverse:timewarp:mode to "RAILS".
        set kuniverse:timewarp:rate to 50.
    }
    wait until ship:altitude < 70000.
    kuniverse:timewarp:cancelwarp().
    wait 5.
    set kuniverse:timewarp:mode to "PHYSICS".
}

function wingedDescent {
    lock throttle to 0.
    lock steering to heading(90, 10, kLandAtm:Roll).
}

function burnExtraFuel {
    lock steering to ship:srfretrograde.
    
    set kuniverse:timewarp:rate to 2.
    wait until ship:altitude < kLandAtm:BurnAlt.
    kuniverse:timewarp:cancelwarp().
    lock throttle to 0.75.
    until (kLandAtm:Coast and ship:deltav:current < kLandAtm:CoastReserve) 
        or stage:number = 0 {
        shipStage().
        wait 0.
    }
    lock throttle to 0.
}

// Burn to descend toward KSC.
// Compensates for spin, but not eccentricity or inclination.
function planLandingBurn {
    local sNorm to shipNorm().
    local ksc to waypoint("ksc").

    local orbW to removeComp(ksc:position - body:position, sNorm).
    local offsetW to rotateVecAround(orbW, sNorm, -kLandAtm:ReturnTanly).
    local shipPos to -body:position.
    local angleToBurn to vectorAngleAround(shipPos, sNorm, offsetW).
    local orbitMeanMotion to 360 / orbit:period.
    local planetMeanMotion to -body:angularVel:y * constant:radtodeg.
    local relativeMeanMotion to orbitMeanMotion - planetMeanMotion.
    local durToBurn to angleToBurn / relativeMeanMotion.
    local burnTime to time + durToBurn.

    local burnPos to shipPAt(burnTime).
    local rb to burnPos:mag.
    local rp to body:radius + kLandAtm:EntryPe.
    local vb to sqrt(2 * ship:body:mu * rp / rb / (rp + rb)).
    local burnStart to removeComp(shipVAt(burnTime), burnPos).
    local burnMag to vb - burnStart:mag.
    add node(burnTime, 0, 0, burnMag).
}
