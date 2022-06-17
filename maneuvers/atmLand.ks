@LAZYGLOBAL OFF.

declare global kAtmLand to lexicon().

set kAtmLand:kEntryPe to 45000.
set kAtmLand:kBurnAlt to 50000.
set kAtmLand:kProAlt to 40000.
set kAtmLand:kReturnLon to 170.
set kAtmLand:kWinged to false.

function atmLandInit {
    set kuniverse:timewarp:mode to "RAILS".
    set kuniverse:timewarp:rate to 50.
}

function atmLandSuccess {
    return ship:status = "LANDED" or ship:status = "SPLASHED".
}

function atmLandLoop {
    if ship:periapsis > kAtmLand:kEntryPe {
        retroBurn().
    } else if ship:altitude > 70000 {
        lock throttle to 0.
        set kuniverse:timewarp:rate to 50.
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

function retroBurn {
    if ship:longitude < kAtmLand:kReturnLon
        or ship:longitude > (kAtmLand:kReturnLon + 5) {
        return.
    }

    set kuniverse:timewarp:rate to 1.
    lock steering to ship:retrograde.
    if vang(ship:facing:vector, ship:retrograde:vector) > 25 {
        lock throttle to 0.
    } else {
        lock throttle to 1.
    }
}