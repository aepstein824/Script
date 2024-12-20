@LAZYGLOBAL OFF.

runOncePath("0:phases/dockrecv.ks").
runOncePath("0:common/ship.ks").
ensureHibernate().
brakes on.

// only one core should control the steering, choose lowest uid
local amSmallest to true.
local procs to list().
list processors in procs.
local myid to core:part:uid.
for p in procs {
    if p:part:uid < myid {
        set amSmallest to false.
        break.
    }
}

if ship:name = activeShip:name {
    core:doevent("Open Terminal").
} else {
    if amSmallest {
        print "Am smallest, docking".
        dockRecv().
    } else {
        print "Am not smallest, doing nothing".
    }
}