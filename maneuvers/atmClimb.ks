@LAZYGLOBAL OFF.

declare global kAtmClimbParams to lexicon().

set kAtmClimbParams:kTurn to 10.
set kAtmClimbParams:kClimbAp to 85000.
set kAtmClimbParams:kBurnHeight to 80000.
set kAtmClimbParams:kClimbPe to 71000.
set kAtmClimbParams:kLastStage to 0.
set kAtmClimbParams:kThrottleTurn to 0.8.

global steer to ship:facing.
global throt to 0.

function atmClimbSuccess  {
    return ship:obt:periapsis > kAtmClimbParams:kClimbPe.
}

function atmClimbInit {
    lock steering to steer.
    lock throttle to throt.
}

function atmClimbLoop {
    local surfaceV to ship:velocity:surface:mag.

    if surfaceV <  60 {
        verticalClimb().
    } else if surfaceV < 150 {
        set steer to acHeading(90 - kAtmClimbParams:kTurn).
    } else if ship:apoapsis < kAtmClimbParams:kClimbAp {
        gravityTurn().
    } else if ship:altitude < kAtmClimbParams:kBurnHeight {
        warpUp().
    } else if not atmClimbSuccess() {
        circularize().
    }

    handleStage().

    wait 0.
}

function atmClimbCleanup {
    lock throttle to 0.
    kuniverse:timewarp:cancelwarp.
}

function handleStage {
    declare local shouldStage to ((maxThrust = 0 or solidCheck) 
        and stage:ready
        and stage:number >= kAtmClimbParams:kLastStage).

    if shouldStage {
        print "Staging " + stage:number.
        stage.
    }
}

function solidCheck {
    for res in ship:resources {
        if res:name = "SOLIDFUEL" and res:amount = 0
            and not res:parts:empty() {
            print "Solid Fuel depleted.".
            return true.
        }
    }

    return false.
}

function verticalClimb {
    set steer to acHeading(90).
    set throt to 1.
}

function gravityTurn {
    set steer to ship:srfPrograde.
    set throt to kAtmClimbParams:kThrottleTurn.
}

function warpUp {
    set steer to ship:srfPrograde.
    set throt to 0.
    set kuniverse:timewarp:rate to 2.
}

function circularize {
    set steer to acHeading(0).
    if vang(ship:facing:vector, acHeading(0):vector) > 10 {
        set kuniverse:timewarp:rate to 1.
        set throt to 0.
    } else {
        set kuniverse:timewarp:rate to 2.
        set throt to 1.
    }
}

function acHeading {
    parameter pitch.
    return heading (90, pitch, 0).
}