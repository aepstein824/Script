@LAZYGLOBAL OFF.

declare global kClimb to lexicon().

set kClimb:Turn to 10.
set kClimb:VertV to 60.
set kClimb:SteerV to 150.
set kClimb:ClimbAp to 85000.
set kClimb:BurnHeight to 80000.
set kClimb:ClimbPe to 71000.
set kClimb:LastStage to 0.
set kClimb:ClimbA to 1.8.
set kClimb:TLimAlt to 5000.

global steer to ship:facing.
global throt to 0.

function climbSuccess  {
    return ship:obt:periapsis > kClimb:ClimbPe.
}

function climbInit {
    lock steering to steer.
    lock throttle to throt.
}

function climbLoop {
    local surfaceV to ship:velocity:surface:mag.

    if surfaceV <  kClimb:VertV {
        verticalClimb().
    } else if surfaceV < kClimb:SteerV {
        set steer to acHeading(90 - kClimb:Turn).
        set throt to slowThrottle().
    } else if ship:apoapsis < kClimb:ClimbAp {
        gravityTurn().
    } else if ship:altitude < kClimb:BurnHeight {
        warpUp().
    } else if not climbSuccess() {
        circularize().
    }

    handleStage().

    wait 0.
}

function climbCleanup {
    lock throttle to 0.
    kuniverse:timewarp:cancelwarp.
}

function slowThrottle {
    local goal to 9.81 * ship:mass * kClimb:ClimbA.
    local engs to list().
    list engines in engs. 
    local throttleThrust to ship:maxThrust.
    for e in engs {
        if e:throttlelock {
            set goal to goal - e:maxThrust.
            set throttleThrust to throttleThrust - e:maxThrust.
        }
    }
    if (throttleThrust <= 0) {
        return 0.
    }
    return goal / throttleThrust.
}

function handleStage {
    declare local shouldStage to ((maxThrust = 0 or solidCheck) 
        and stage:ready
        and stage:number >= kClimb:LastStage).

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
    set throt to slowThrottle()..
}

function gravityTurn {
    set steer to ship:srfPrograde.
    if (ship:altitude < kClimb:TLimAlt) {
        set throt to slowThrottle().
    }
    else {
        set throt to 1.
    }
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