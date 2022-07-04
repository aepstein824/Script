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
    local ve to flowIsp[1] * 9.81.
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
    declare local shouldStage to maxThrust = 0 and stage:ready
        and stage:number > 0.

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