clearscreen.

print "Waiting for ship to unpack.".
wait until ship:unpacked.
print "Ship is now unpacked.".

// part setup
set barometers to ship:partsdubbedpattern("science jr").
if not (barometers:length = 4) {
  print "ERROR: Wrong barometer count found".
}.

declare function measure {
    parameter ind.
    local b0part to barometers[ind].
    local b0mod to b0part:getmodule("ModuleScienceExperiment").
    b0mod:deploy.
    wait until b0mod:hasdata().
}.

// pad experiment
print "Pad experiment".
measure(0).

print "Launch".
lock steering to up.
lock throttle to 100.
stage.


// land trigger
when ship:apoapsis > 80000 then {
    print "80km ap reached".
    lock throttle to 0.
    stage.
}.

// science loop
set need_low to true.
set need_high to true.
set need_space to true.

until not need_space {
  if ship:altitude > 100 and need_low {
    set need_low to false.
    print "Low experiment".
    measure(1).
  } else if ship:altitude > 20000 and need_high {
    set need_high to false.
    print "High experiment".
    measure(2).
  } else if ship:altitude > 70100 and need_space {
    set need_space to false.
    print "Space experiment".
    measure(3).
  }
}

wait until ship:altitude < 40000.
print "Slowing for landing".
set throttle to 5.

set ship:control:pilotmainthrottle to 0.
print "SCRIPT OVER".
wait until false.