@LAZYGLOBAL OFF.

runOncePath("0:common/control.ks").
runOncePath("0:common/operations.ks").

sas off.

local hasDocked to false.
for port in ship:dockingports {
    if port:hasPartner() {
        set hasDocked to true.
        break.
    }
}
if not hasDocked {
    rcs on.
}

local ourPort to getPort(ship).
opsControlFromPort(ourPort).
local theirPort to getPort(activeShip).

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
rcs off.