@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:phases/travel.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/launchToOrbit.ks").

local buttonNames to list("exit", "travel", "dock", "launch", "land", "node").
clearGuis().
local gui to gui(0).
createButtons().
gui:show().

local todo to "".
local arg0 to "".
local arg1 to "".

until false {
    wait until todo <> "".
    print todo + ", " + arg0 + ", " + arg1.
    if todo = "exit" {
        break.
    }
    doSomething(todo, arg0, arg1).
    set todo to "".
    gui:show().
}

function createButtons {
    for b in buttonNames {
        local button to gui:addbutton(b).
        function clickChecker {
            parameter bname.
            set todo to bname.
            set arg0 to arg0f:text.
            set arg1 to arg1f:text.
            gui:hide().
        }
        set button:onclick to clickChecker@:bind(b).
    }
    local fields to gui:addhlayout().
    local arg0f to fields:addtextfield("").
    local arg1f to fields:addtextfield("").
}

function doSomething {
    parameter it, a0, a1.

    if it = "travel" {
        setTargetTo(a0).
        local travelCtx to lexicon(
            "dest", target 
        ).
        if a1 = "polar" {
            set travelCtx:inclination to 90.
        } 
        travelTo(travelCtx).
    } else if it = "dock" {
        set target to a0.
        rcsApproach().
    } else if it = "launch" {
        launchQuicksave("interactive").
        ensureHibernate().
        launchToOrbit().
    } else if it = "node" {
        nodeExecute().
    }
}

gui:hide().