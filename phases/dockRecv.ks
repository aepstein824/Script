@LAZYGLOBAL OFF.

rcs off.
ship:dockingports[0]:GETMODULE("ModuleDockingNode")
    :DOEVENT("Control From Here").
lock steering to target:position.
wait until target:position:mag < 10.
unlock steering.
