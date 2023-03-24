@LAZYGLOBAL OFF.


function shipNorm {
    return vCrs(ship:prograde:vector, ship:position - body:position):normalized.
}

function shipPAt {
    parameter t.
    return positionAt(ship, t) - body:position.
}

function shipPAtPe {
    return shipPAt(obt:eta:periapsis + time).
}

function shipVAt {
    parameter t.
    return velocityAt(ship, t):orbit.
}

function shipFlowIsp {
    local totalFuelFlow to 0.
    local totalIsp to 0.
    local engineList to List().
    list engines in engineList.
    for engine in engineList {
        if engine:ignition {
            local massFlow to 0.
            for r in engine:consumedResources:values {
                set massFlow to massFlow 
                    + r:maxfuelflow * r:density.
            }
            set totalFuelFlow to totalFuelFlow + massFlow.
            set totalIsp to totalIsp + engine:isp * massFlow.
        }
    }
    return List(totalFuelFlow, totalIsp / totalFuelFlow).
}

function shipTimeToDV {
    parameter dv.
    local flowIsp to shipFlowIsp().
    local flow to flowIsp[0].
    local ve to flowIsp[1] * 9.80655.
    local burnRatio to constant:e ^ (-1 * dv / ve).
    local rocketEstimate to (1 - burnRatio)  * ship:mass / flow. 
    return rocketEstimate.
}

function ensureHibernate {
    for part in ship:parts {
        for modName in part:modules {
            if modName:contains("command") {
                local module to part:getmodule(modName).
                if module:hasField("Hibernate in Warp") {
                    module:setfield("Hibernate in Warp", "Auto").
                }
            }
        }
    }
}

function shipStage {
    local shouldStage to maxThrust = 0 and stage:ready and stage:number > 0.

    if shouldStage {
        print "Staging " + stage:number.
        stage.
    }
}

function shipAccel {
    return ship:maxThrust / ship:mass.
}

function nextNodeOverBudget {
    parameter budget.

    return ship:deltav:current - nextNode:deltav:mag < budget.
}

function printPids {
    print "total angle error: " + vecround(v(
        steeringManager:pitcherror,
        steeringManager:yawerror,
        steeringManager:rollerror
    ), 5).
    function printOnePid {
        parameter name, pid.
        print name + ": e=" + round(pid:error * constant:radtodeg, 2)
            + " out=" + pid:output * constant:radtodeg.
            // + " chg=" + round(pid:changerate * constant:radtodeg, 2).
    }
    printOnePid("pitch", steeringManager:pitchpid).
    printOnePid("yaw  ", steeringManager:yawpid).
    printOnePid("roll ", steeringManager:rollpid).
}

function shipHeading {
    local northPole to latlng(90, 0).
    local comp to mod(360 - northPole:bearing, 360).
    return comp.
}

function shipLevel {
    local out to -body:position.
    local lev to vxcl(out, velocity:surface).
    local level to lookDirUp(lev, out).
    return level.
}

function shipFacingRcs {
    parameter vt.
    local vFace to ship:facing:inverse * vt.
    set ship:control:translation to vFace.
}

function shipProcessors {
    local procs to list().
    list processors in procs.
    return procs.
}

function procCount {
    local procs to shipProcessors().
    return procs:length().
}

function shipControlFromCommand {
    // TODO choose this in some reasonable way
    local commandMod to ship:modulesnamed("ModuleCommand")[0].
    commandMod:part:controlfrom().
}

function shipIsLandOrSplash {
    return status = "LANDED" or status = "SPLASHED".
}