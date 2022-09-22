@LAZYGLOBAL OFF.

declare global kClimb to lexicon().

set kClimb:Turn to 2.
set kClimb:VertV to 60.
set kClimb:SteerV to 150.
set kClimb:ClimbAp to 75000.
set kClimb:ClimbPe to 73000.
set kClimb:LastStage to 0.
set kClimb:ClimbA to 1.5.
set kClimb:TLimAlt to 10000.
set kClimb:Heading to 90.
set kClimb:Roll to 0.

local jettisoned to false.

function climbSuccess  {
    return ship:obt:periapsis > kClimb:ClimbPe.
}

function climbInit {
    set jettisoned to false.
}

function climbLoop {
    local surfaceV to ship:velocity:surface:mag.

    if surfaceV <  kClimb:VertV {
        verticalClimb().
    } else if surfaceV < kClimb:SteerV {
        lock steering to acHeading(90 - kClimb:Turn).
        lock throttle to slowThrottle().
    } else if ship:apoapsis < kClimb:ClimbAp {
        gravityTurn().
    } else if ship:altitude < 70000 {
        warpUp().
    } else {
        if not jettisoned {
            jettisonFairings().
            set jettisoned to true.
        }
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
    declare local shouldStage to ((maxThrust = 0 or solidCheck()) 
        and stage:ready
        and stage:number >= kClimb:LastStage).

    if shouldStage {
        print "Staging " + stage:number.
        lock throttle to 0.2.
        stage.
        wait 1.
    }
}

function solidCheck {
    local allEngines to list().
    list engines in allEngines.
    for e in allEngines {
        if e:ignition and e:flameout and e:throttlelock {
            print "Solid Fuel depleted.".
            return true.
        }
    }

    return false.
}

function verticalClimb {
    lock steering to acHeading(90).
    lock throttle to slowThrottle()..
}

function gravityTurn {
    lock steering to lookDirUp(ship:velocity:surface, -body:position).
    if (ship:altitude < kClimb:TLimAlt) {
        lock throttle to slowThrottle().
    }
    else {
        lock throttle to 1.
    }
}

function warpUp {
    lock throttle to 0.
    lock steering to srfPrograde.
    set kuniverse:timewarp:rate to 2.
}

function circularize {
    lock steering to removeComp(ship:velocity:orbit, body:position).
    if vang(ship:facing:vector, steering) > 10
        or not climbShouldCircleBurn() { 
        set kuniverse:timewarp:rate to 1.
        lock throttle to 0.05. // engine gimbal will help turn
    } else {
        set kuniverse:timewarp:rate to 2.
        lock throttle to 1.
    }
}

function climbShouldCircleBurn {
    if obt:eta:apoapsis > obt:eta:periapsis {
        return true.
    }
    local cSpd to sqrt(body:mu / (kClimb:ClimbAp + body:radius)).
    local apTime to time + obt:eta:apoapsis.
    local apSpd to shipVAt(apTime):mag.
    return obt:eta:apoapsis < (shipTimeToDV(cSpd - apSpd) / 2 + 5).
}

function acHeading {
    parameter pitch.
    return heading (kClimb:Heading, pitch, kClimb:Roll).
}