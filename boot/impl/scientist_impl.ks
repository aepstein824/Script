@LAZYGLOBAL OFF.

runOncePath("0:common/operations.ks").

until false {
    wait 10.
    doUseOnceScience().
}