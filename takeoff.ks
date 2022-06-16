clearscreen.

set constants to readjson("0:/craftData/plank.json").

print constants.

set steeringmanager:yawpid:ki to 0.
set steeringmanager:pitchpid:ki to 0.
set steeringmanager:rollpid:ki to 0.

stage.
lock throttle to 1.
lock steering to ship:facing.
wait until ship:groundspeed > 80.
lock steering to ship:facing + r(0, 15, 0).
wait until false.