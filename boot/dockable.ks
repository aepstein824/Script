wait 1.
switch to 0.
runOncePath("0:phases/dockrecv.ks").
if ship:name = activeShip:name {
    core:doevent("Open Terminal").
} else {
    dockRecv().
}