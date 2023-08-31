local measurements to list().

local start to time.
local throt to 0.
lock throttle to throt.
stage.

// set measurements to list().
// set start to time.
// local goal to ship:maxThrust / 2.
// until false {
//     if time > start + 10 {
//         break.
//     }

//     set throt to 0.5.
//     measurements:add(ship:thrust / goal).
//     wait 0.
// }
// for m in measurements:sublist(0, 500) { 
//     log m to "mylog.csv".
// }

// set measurements to list().
// wait 60.
// set start to time.
// until false {
//     if time > start + 10 {
//         break.
//     }

//     set throt to 0.0.
//     measurements:add(ship:thrust / goal).
//     wait 0.
// }
// for m in measurements:sublist(0, 500) { 
//     log m to "mylogD.csv".
// }

set measurements to list().
local goal to ship:maxThrust / 2.
set throt to 1.
local lastThrust to 0.
local dThrust to 0.
until ship:thrust > goal {
    local nowThrust to ship:thrust.
    set dThrust to (nowThrust - lastThrust) / 0.02.
    if nowThrust + .05 * dThrust > goal {
        break.
    }
    set lastThrust to nowThrust.
}
set start to time.
until false {
    if time > start + 10 {
        break.
    }

    set throt to 0.5.
    measurements:add(ship:thrust / goal).
    wait 0.
}
for m in measurements:sublist(0, 500) { 
    log m to "mylogS.csv".
}

print measurements:length.