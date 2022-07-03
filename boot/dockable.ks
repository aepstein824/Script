wait 1.
switch to 0.
if ship:name = activeShip:name {
    core:doevent("Open Terminal").
} else {
    runOncePath("0:phases/dockrecv").
}