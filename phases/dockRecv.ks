@LAZYGLOBAL OFF.

sas off.
rcs on.
ship:dockingports[0]:GETMODULE("ModuleDockingNode")
    :DOEVENT("Control From Here").

lock dist to activeShip:position - ship:position.
lock steering to dist.
wait until dist:mag < 10.
rcs off.
unlock steering.