@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:phases/travel.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/waypoints.ks").

local buttonNames to list(
    "exit", "travel", "dock", "launch", 
    "land", "node", "circle", "ground", "refresh"
    ).
clearGuis().
local menu to gui(300).
createButtons().
menu:show().

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
    unlock steering.
    unlock throttle.
    set todo to "".
    menu:show().
}

function createButtons {
    for b in buttonNames {
        local button to menu:addbutton(b).
        function clickChecker {
            parameter bname.
            set todo to bname.
            set arg0 to arg0f:text.
            set arg1 to arg1f:text.
            menu:hide().
        }
        set button:onclick to clickChecker@:bind(b).
    }
    local fields to menu:addhlayout().
    local arg0f to fields:addtextfield("").
    local arg1f to fields:addtextfield("").
}

function doSomething {
    parameter it, a0, a1.

    sas off.
    if it = "travel" {
        // unsetTarget().
        if not hasTarget {
            setTargetTo(a0).
        }
        local dest to choose target if hasTarget else body(a0).
        local travelCtx to lexicon(
            "dest", dest 
        ).
        if a1 = "polar" {
            set travelCtx:inclination to 90.
        } 
        travelTo(travelCtx).
    } else if it = "dock" {
        if not hasTarget {
            set target to a0.
        }
        rcsApproach().
    } else if it = "launch" {
        if a0 = "polar" {
            set kClimb:Heading to -20.
        }
        launchQuicksave("interactive").
        ensureHibernate().
        launchToOrbit().
    } else if it = "land" {
        local l0 to a0:tonumber(0).
        local l1 to a1:tonumber(0).
        local lz to latlng(l0, l1).
        vacDescendToward(lz).
        vacLand(). 
    } else if it = "node" {
        nodeExecute().
    } else if it = "circle" {
        local alti to a0:tonumber(kWarpHeights[body]).
        circleNextExec(alti).
        // local inc to a1:tonumber(obt:inclination).
        // matchPlanes(inclinationToNorm(inc)).
        // nodeExecute().
    } else if it = "ground" {
        vacLand(). 
    } else if it = "refresh" {
        opsCollectRestoreScience().
        opsRefuel().
    }
}

menu:hide().