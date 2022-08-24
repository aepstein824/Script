@LAZYGLOBAL OFF.

runOncePath("0:common/operations.ks").

sas off.
rcs on.
getPort(ship):GETMODULE("ModuleDockingNode")
    :DOEVENT("Control From Here").

print "Waiting till unpacked".
wait until ship:unpacked.
print "Unpacked".
lock dist to activeShip:position - ship:position.
lock steering to dist.
wait until dist:mag < 10.
rcs off.
unlock steering.