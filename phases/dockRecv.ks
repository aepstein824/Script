@LAZYGLOBAL OFF.

runOncePath("0:common/control.ks").
runOncePath("0:common/operations.ks").

function dockRecv {
    if ship = kuniverse:activevessel {
        print "Already the active ship".
    }
    print "Begin docking".
    sas off.
    local hasDocked to false.
    for port in ship:dockingports {
        if port:hasPartner() {
            set hasDocked to true.
            break.
        }
    }
    if not hasDocked {
        // causes instability
        enableRcs().
    }
    lights on.

    local ports to opsPortFindPair(activeShip).
    local ourPort to ports[0].
    local theirPort to ports[1].
    opsControlFromPort(ourPort).

    print "Waiting till unpacked".
    wait until ship:unpacked.
    print "Unpacked".
    controlLock().
    until false {
        local dist to theirPort:position - ourPort:position.
        set controlSteer to dist.
        if dist:mag < 1 {
            break.
        }
        wait 0.
    }
    print "Ship close enough".
    controlUnlock().
    disableRcs().
}