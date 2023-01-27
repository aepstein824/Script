wait 1.
switch to 0.
if ship:name = activeShip:name {
    core:doevent("Open Terminal").
} else {
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
    if amSmallest {
        print "Am smallest, docking".
        runOncePath("0:phases/dockrecv").
    } else {
        print "Am not smallest, doing nothing".
    }
}