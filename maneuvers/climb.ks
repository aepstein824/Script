@LAZYGLOBAL OFF.

runOncePath("0:common/control").
runOncePath("0:common/orbital").

declare global kClimb to lexicon().

set kClimb:Turn to 3.
set kClimb:VertV to 60.
set kClimb:SteerV to 200.
set kClimb:ClimbAp to 80000.
set kClimb:ClimbPe to 71000.
set kClimb:LastStage to 0.
set kClimb:ClimbA to 1.5.
set kClimb:TLimAlt to 10000.
set kClimb:Heading to 90.
set kClimb:Roll to 0.
set kClimb:DragFactor to 1.05.

local jettisoned to false.

function climbSuccess  {
    return ship:obt:periapsis > kClimb:ClimbPe.
}

function climbInit {
    set jettisoned to false.
    controlLock().
}

function climbLoop {
    local surfaceV to ship:velocity:surface:mag.

    handleStage().

    if surfaceV <  kClimb:VertV {
        verticalClimb().
    } else if surfaceV < kClimb:SteerV {
        set controlSteer to acHeading(90 - kClimb:Turn).
        set controlThrot to slowThrottle().
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

    wait 0.
}

function climbCleanup {
    set controlThrot to 0.
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
    local shouldStage to ((maxThrust = 0 or solidCheck()) 
        and stage:ready
        and stage:number >= kClimb:LastStage).

    if shouldStage {
        print " Staging " + stage:number.
        set controlThrot to 0.4.
        stage.
        wait 0.5.
    }
}

function solidCheck {
    local allEngines to list().
    list engines in allEngines.
    for e in allEngines {
        if e:ignition and e:flameout and e:throttlelock {
            print " Solid Fuel depleted.".
            return true.
        }
    }

    return false.
}

function verticalClimb {
    set controlSteer to acHeading(90).
    set controlThrot to slowThrottle().
}

function gravityTurn {
    local pitch to arccos(groundspeed / airspeed).
    set controlSteer to acHeading(pitch).
    if (ship:altitude < kClimb:TLimAlt) {
        set controlThrot to slowThrottle().
    }
    else {
        set controlThrot to 1.
    }
}

function warpUp {
    set controlThrot to 0.
    set controlSteer to srfPrograde.
    set kuniverse:timewarp:rate to 2.
}

function circularize {
    set kuniverse:timewarp:rate to 1.
    local pitch to 0.
    if obt:eta:apoapsis > obt:eta:periapsis {
        local acc to ship:maxthrust / ship:mass.
        local gacc to gat(altitude).
        local centripetalAcc to velocity:orbit:mag ^ 2 
            / (altitude + body:radius).
        local verticalAcc to gacc - centripetalAcc.
        set pitch to arcsin(verticalAcc / acc).
        set pitch to min(pitch, 30).
    }
    set controlSteer to acHeading(pitch).
    set controlThrot to climbCircularizeThrottle().
}

function climbOrbitSpeed {
    local ap to kClimb:ClimbAp + body:radius.
    local semi to (kClimb:ClimbAp + kClimb:ClimbPe) / 2 + body:radius.
    local cSpd to orbitalSpeed(body:mu, semi, ap).
    return cSpd.
}

function climbCircularizeThrottle {
    if obt:eta:apoapsis > obt:eta:periapsis {
        return 1.0.
    }
    if vang(facing:forevector, controlSteer:forevector) > 10 {
        return 0.05.
    }
    local cSpd to climbOrbitSpeed().
    local apTime to time:seconds + obt:eta:apoapsis.
    local apSpd to shipVAt(apTime):mag.
    local burnDur to shipTimeToDV(cSpd - apSpd) / 2.
    local apDur to obt:eta:apoapsis.
    local throt to invlerp(burnDur - apDur, -5, 0) + 0.05.

    return throt.
}

function acHeading {
    parameter pitch.
    return heading (kClimb:Heading, pitch, kClimb:Roll).
}

function climbIncToHdg {
    parameter inc.
    local rotSpeed to v(0, 0, -1 * velocity:orbit:mag).
    local obtSpd to kClimb:DragFactor * climbOrbitSpeed().
    // v(1,0,0) means north means 90 inclination
    // inclinations are ACTUALLY right handed in ksp, but the coordinates are left handed
    // therefore, use -unitY as the axis
    // inc 0 means unit Z.
    local incSpeed to rotateVecAround(obtSpd * unitZ, -unitY, inc).
    local summed to rotSpeed + incSpeed.
    // Headings are from north, which is unitX
    local climbHeading to vectorAngleAround(unitX, unitY, summed).
    return climbHeading.
}