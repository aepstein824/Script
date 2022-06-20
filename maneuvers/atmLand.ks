@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:common/ship.ks").

declare global kAtmLand to lexicon().

set kAtmLand:kEntryPe to 45000.
set kAtmLand:kBurnAlt to 50000.
set kAtmLand:kProAlt to 40000.
set kAtmLand:kReturnTanly to 100.
set kAtmLand:kWinged to false.

function atmLandInit {
    set kuniverse:timewarp:mode to "RAILS".
    set kuniverse:timewarp:rate to 50.
}

function atmLandSuccess {
    return ship:status = "LANDED" or ship:status = "SPLASHED".
}

function atmLandLoop {
    if ship:altitude > 70000 {
        lock throttle to 0.
        if kuniverse:timewarp:mode <> "RAILS" {
            kuniverse:timewarp:cancelwarp().
            wait 1.
        }
        set kuniverse:timewarp:mode to "RAILS".
        set kuniverse:timewarp:rate to 100.
    } else if ship:altitude > kAtmLand:kBurnAlt {
        lock steering to ship:srfretrograde.
        set kuniverse:timewarp:rate to 2.
    } else if ship:altitude > kAtmLand:kProAlt {
        if maxThrust = 0 and kAtmLand:kWinged {
            lock steering to heading(90, 10, -90).
        } else {
            lock throttle to 1.
            lock steering to ship:srfretrograde.
        }
    } 

    atmLandStage().
    wait 0.
}

function atmLandStage {
    declare local shouldStage to maxThrust = 0 and stage:ready
        and stage:number > 0.

    if shouldStage {
        print "Staging " + stage:number.
        stage.
    }
}

function planLandingBurn {
    local sNorm to shipNorm().

    local wpoints to allWaypoints().
    local ksc to wpoints[wpoints:length - 1].
    for w in allWaypoints() {
        if w:name = ksc {
            set ksc to w.
        }
    }

    // doesn't work, need to account for eccentricity and spin
    local orbW to removeComp(ksc:position - body:position, sNorm).
    local pePos to shipPAtPe().
    local wTanly to vectorAngleAround(pePos, sNorm, orbW).
    local burnTanly to mod(wTanly - kAtmLand:kReturnTanly + 360, 360).
    local burnTime to timeBetweenTanlies(obt:trueanomaly, burnTanly, obt) + time.
    local burnPos to shipPAt(burnTime).
    local rb to burnPos:mag.
    local rp to body:radius + kAtmLand:kEntryPe.
    local vb to sqrt(2 * ship:body:mu * rb / rp / (rp + rb)).
    print "vb = " + vb.
    local burnStart to shipVAt(burnTime).
    local burnMag to vb - burnStart:mag.
    add node(burnTime, 0, 0, -1 * burnMag).
}

function landingBurn {
    changePeAtAp(kAtmLand:kEntryPe).
    nodeExecute().
}