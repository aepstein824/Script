@LAZYGLOBAL OFF.

runOncePath("0:maneuvers/node.ks").

until not hasNode {
    nodeExecute().
}