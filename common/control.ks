@LAZYGLOBAL OFF.

global controlSteer to facing.
global controlThrot to 0.

function controlLock {
    lock steering to controlSteer.
    lock throttle to controlThrot.
}

function controlUnlock {
    unlock steering.
    unlock throttle.
}