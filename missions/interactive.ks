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
    "land", "node", "circle", "refresh",
    "science", "mine", "undock"
    ).
clearGuis().
local menu to gui(300).
createButtons().
menu:show().

local todo to "".
local argStringBacking to "".

until false {
    wait until todo <> "".
    print todo + ", " + argStringBacking.
    if todo = "exit" {
        break.
    }
    doSomething(todo, argStringBacking).
    unlock steering.
    unlock throttle.
    set todo to "".
    menu:show().
}
menu:hide().

function createButtons {
    for b in buttonNames {
        local button to menu:addbutton(b).
        function clickChecker {
            parameter bname.
            set todo to bname.
            set argStringBacking to arg0f:text.
            menu:hide().
        }
        set button:onclick to clickChecker@:bind(b).
    }
    local fields to menu:addhlayout().
    local arg0f to fields:addtextfield("").
}

function doSomething {
    parameter it, argString.
    local args to argString:split(",").
    local a0 to args[0].

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
        if args.length > 1 {
            local a1 to args[1].
            if a1 = "lead" or a1 = "lag" {
                local matchDest to dest.
                set travelCtx:dest to dest:obt:body.
                local match to lex("it", matchDest).
                local safeLead to obtSafeLead(matchDest).
                local lead to choose safeLead if a1 = "lead" else -3 * safeLead.
                set match:offset to lead.
                set travelCtx:match to match.

            }
            if a1 = "polar" {
                set travelCtx:inclination to 90.
            } 
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
        local l1 to args[1]:tonumber(0).
        local lz to latlng(l0, l1).
        local flatLz to geoNearestFlat(lz).
        vacDescendToward(flatLz).
        vacLandGeo(flatLz). 
    } else if it = "node" {
        nodeExecute().
    } else if it = "circle" {
        local alti to a0:tonumber(opsScienceHeight(body)).
        circleNextExec(alti).
        // local inc to a1:tonumber(obt:inclination).
        // matchPlanes(inclinationToNorm(inc)).
        // nodeExecute().
    } else if it = "refresh" {
        opsCollectRestoreScience().
        opsRefuel().
    } else if it = "science" {
        doUseOnceScience().
        opsCollectRestoreScience().
    } else if it = "mine" {
        opsISRUMineAll().
    } else if it = "undock" {
        opsUndockPart(core:part).
        wait 0.5.
        set kuniverse:activevessel to core:vessel.
    }

}
