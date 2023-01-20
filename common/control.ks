@LAZYGLOBAL OFF.

global controlSteer to facing.
global controlThrot to 0.
global controlLocked to false.

function controlLock {
    set controlLocked to true.
    lock steering to controlSteer.
    lock throttle to controlThrot.
}

function controlUnlock {
    set controlLocked to false.
    unlock steering.
    unlock throttle.
}

function controlMaybeLock {
    if controlLocked = false {
        set controlLocked to true.
        lock steering to controlSteer.
        lock throttle to controlThrot.
    }
}

function controlMaybeUnlock {
    if controlLocked = true {
        set controlLocked to false.
        unlock steering.
        unlock throttle.
    }
}