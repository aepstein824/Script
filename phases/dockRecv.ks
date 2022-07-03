@LAZYGLOBAL OFF.

rcs off.
ship:dockingports[0]:GETMODULE("ModuleDockingNode")
    :DOEVENT("Control From Here").

lock steering to activeShip:position.
wait until activeShip:position:mag < 10.
unlock steering.