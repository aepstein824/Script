clearscreen.
set kTurn to 20.
set kHeight to 80000.
set kBurn to 45000.
set lastStage to 4.

wait until ship:unpacked.

print "Preparing to launch".
stage.
lock throttle to 100.
set steer to climbHeading(90).
lock steering to steer.

until ship:apoapsis > kHeight + 3000 {
 local surfacev is ship:velocity:surface:mag.
 solidCheck().

  if stage:number >= lastStage 
    and stage:ready 
    and (maxthrust = 0 or solidCheck()) {
      print "Staging" + maxThrust.
      stage.
      print maxThrust.
  }

 if surfacev < 300 {
  set steer to climbHeading(90).
 }
 else {
  local angle is 90 - ((surfacev - 300) / kTurn).
  if angle < 10 {
      set angle to 10.
  }
  set steer to climbHeading(angle).
 }
}

print "Reached ap, warping to height".
set steer to ship:srfprograde.
lock throttle to 0.
set kuniverse:timewarp:mode to "PHYSICS".
set kuniverse:timewarp:warp to 4.
wait until ship:altitude > kHeight.
kuniverse:timewarp:cancelwarp().

print "Circle!".
set steer to climbHeading(0).
wait 1.

lock throttle to 100.
until ship:periapsis > 75000 {
  if maxthrust = 0 and stage:number >= lastStage and stage:ready {
      print "Staging".
      stage.
  }
}
lock throttle to 0.

wait 1.
print "Reentry Wait".
set kuniverse:timewarp:mode to "RAILS".
set kuniverse:timewarp:rate to 1000.
wait 1 * 60 * 60.
set kuniverse:timewarp:rate to 50.
wait until ship:longitude > 120 and ship:longitude < 125.
kuniverse:timewarp:cancelwarp().

print "Reentry Burn".
lock steering to ship:retrograde.
wait 3.
lock throttle to 100.
wait until ship:periapsis < kBurn.
print "Reentry Fall".
lock throttle to 0.
wait 1.
set kuniverse:timewarp:rate to 50.
wait until ship:altitude < 69000.
set kuniverse:timewarp:rate to 3.
wait until ship:altitude < kBurn.
print "Final Burn".
lock steering to ship:srfprograde + R(10, 0, 0).
wait 3.
lock throttle to 100.

wait until maxThrust = 0.
stage.

print "Just don't overheat or crash!".
wait until false.

declare function climbHeading {
    parameter pitch.
    return heading(90, pitch, -90).
}.

declare function solidCheck {
    for res in ship:resources {
        if res:name = "SOLIDFUEL" and res:amount = 0
            and not res:parts:empty() {
            print "Solid Fuel depleted.".
            return true.
        }
    }

    return false.
}