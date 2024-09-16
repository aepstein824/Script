@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").

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

function shipEngineInfo {
    local totalFuelFlow to 0.
    local totalIsp to 0.
    local totalThust3d to zeroV:vec.

    for engine in ship:engines {
        if engine:ignition {
            local thrust to engine:maxthrust * -1 * engine:facing:vector.


            set totalFuelFlow to totalFuelFlow + engine:maxmassflow.
            set totalIsp to totalIsp + engine:isp * engine:maxmassflow.
            set totalThust3d to totalThust3d + thrust.
        }
    }
    return lexicon(
        "massFlow", totalFuelFlow,
        "isp", totalIsp / totalFuelFlow,
        "thrust3d", totalThust3d
    ).
}

function shipFindThrustController {
    function controllerDotThrust {
        parameter controller, unitThrust.
        return vdot(-1 * controller:facing:vector, unitThrust).
    }
    local thrust to shipEngineInfo():thrust3d.
    function compareDots {
        parameter a, b.
        return controllerDotThrust(a, thrust) < controllerDotThrust(b, thrust).
    }
    local controllers to mergeList(ship:dockingports, shipCommandParts()).
    local bestController to opsListMax(controllers, compareDots@).
    return bestController.
}

function shipControlFromThrustController {
    local controllerPart to shipFindThrustController().
    controllerPart:controlFrom().
}

function shipTimeToDV {
    parameter dv.
    local engineInfo to shipEngineInfo().
    local flow to engineInfo:massFlow.
    local ve to engineInfo:isp * 9.80655.
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
    if not (stage:ready and stage:number > 0) {
        return.
    }

    if maxThrust = 0 {
        print "Staging " + stage:number + " due to zero total thrust".
        stage.
        return.
    }

    for e in ship:engines {
        if e:ignition and e:flameout {
            print "Staging " + stage:number + " due to flameout of " + e:name.
            stage.
            return.
        }
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

function shipProcessors {
    local procs to list().
    list processors in procs.
    return procs.
}

function procCount {
    local procs to shipProcessors().
    return procs:length().
}

function shipCommandParts {
    local commanders to list().
    for mod in ship:modulesnamed("ModuleCommand") {
        commanders:add(mod:part).
    }
    print commanders.
    return commanders.
}

function shipControlFromCommand {
    // TODO choose this in some reasonable way
    shipCommandParts[0]:controlfrom().
}

function shipIsLandOrSplash {
    return status = "LANDED" or status = "SPLASHED" or status = "PRELAUNCH".
}

function shipActiveEnginesAirbreathe {
    for e in ship:engines {
        if e:ignition {
            for res in e:consumedresources:keys {
                if res:contains("Intake") {
                    return true.
                }
            }
        }
    }
    return false.
}

function shipRcsDoThrust {
    parameter accRaw, rcsInvThrust.

    local accFace to ship:facing:inverse * accRaw.
    local thrustFace to accFace * ship:mass.
    set ship:control:translation to vecMultiplyComps(thrustFace, rcsInvThrust).
}

function shipRcsGetThrust {
    local posThrust to v(0, 0, 0).
    local negThrust to v(0, 0, 0).
    for thruster in ship:rcs {
        local thrusterThrust to thruster:availableThrust.
        for vec in thruster:thrustvectors {
            local facingThrust to facing:inverse * vec.
            set posThrust to posThrust + thrusterThrust * v(
                max(facingThrust:x, 0),
                max(facingThrust:y, 0),
                max(facingThrust:z, 0)
            ).
            set negThrust to negThrust + thrusterThrust * v(
                min(facingThrust:x, 0),
                min(facingThrust:y, 0),
                min(facingThrust:z, 0)
            ).
        }
    }

    // All algorithms will assume symmetry for now.
    return posThrust.
}

function shipRcsInvThrust {
    local rcsThrust to shipRcsGetThrust().
    local rcsInvThrust to vecInvertComps(rcsThrust).
    return rcsInvThrust.
}

function shipActivateAllEngines {
    for e in ship:engines {
        if not e:ignition {
            e:activate.
        }
    }
}


function shipRcsModeALineRatios {
    parameter top, mid, bot.
    print list(top, mid, bot).
    if mid > 0 {
        local k to (top + bot) / (bot - mid).
        return list(1, k, 1 - k).
    } else {
        local k to (top + bot) / (top - mid).
        return list(1 - k, k, 1).
    }
}

function shipRcsModeARatios {
    parameter rcsList, split, face.
    // Configuration A is 24 single thrusters, 6 facing left/right/up/down.
    // Left/right and up/down are balanced separately.
    // They are indexed so that 0,1/2,3/4,5 have the same z axis
    // Can balance between the midpoint of 0,2 and 2,4.
    // Thrusters for fore/aft are assumed to be radially symmetric.


    local ratios to opsListGenerate(0, rcsList:length).
    local faceVec to face:forevector.

    local rightRcs to split:right.
    local lrLineRatios to shipRcsModeALineRatios(
        vdot(rcsList[rightRcs[0]]:position, faceVec),
        vdot(rcsList[rightRcs[2]]:position, faceVec),
        vdot(rcsList[rightRcs[4]]:position, faceVec)
    ).
    set ratios[rightRcs[0]] to lrLineRatios[0].
    set ratios[rightRcs[1]] to lrLineRatios[0].
    set ratios[rightRcs[2]] to lrLineRatios[1].
    set ratios[rightRcs[3]] to lrLineRatios[1].
    set ratios[rightRcs[4]] to lrLineRatios[2].
    set ratios[rightRcs[5]] to lrLineRatios[2].
    local leftRcs to split:left.
    set ratios[leftRcs[0]] to lrLineRatios[0].
    set ratios[leftRcs[1]] to lrLineRatios[0].
    set ratios[leftRcs[2]] to lrLineRatios[1].
    set ratios[leftRcs[3]] to lrLineRatios[1].
    set ratios[leftRcs[4]] to lrLineRatios[2].
    set ratios[leftRcs[5]] to lrLineRatios[2].

    local upRcs to split:up.
    local udLineRatios to shipRcsModeALineRatios(
        vdot(rcsList[upRcs[0]]:position, faceVec),
        vdot(rcsList[upRcs[2]]:position, faceVec),
        vdot(rcsList[upRcs[4]]:position, faceVec)
    ).
    set ratios[upRcs[0]] to udLineRatios[0].
    set ratios[upRcs[1]] to udLineRatios[0].
    set ratios[upRcs[2]] to udLineRatios[1].
    set ratios[upRcs[3]] to udLineRatios[1].
    set ratios[upRcs[4]] to udLineRatios[2].
    set ratios[upRcs[5]] to udLineRatios[2].
    local downRcs to split:down.
    set ratios[downRcs[0]] to udLineRatios[0].
    set ratios[downRcs[1]] to udLineRatios[0].
    set ratios[downRcs[2]] to udLineRatios[1].
    set ratios[downRcs[3]] to udLineRatios[1].
    set ratios[downRcs[4]] to udLineRatios[2].
    set ratios[downRcs[5]] to udLineRatios[2].

    for ind in split:fore {
        set ratios[ind] to 1.
    }
    for ind in split:aft {
        set ratios[ind] to 1.
    }

    return ratios.
}

function shipRcsModeAEnumerate {
    parameter rcsList, face.

    local translators to opsListGenerate(false, rcsList:length).
    local rotators to opsListGenerate(false, rcsList:length).
    local split to lexicon().

    local nameToVec to lexicon(
        "fore", face:forevector,
        "aft", -face:forevector,
        "up", face:upvector,
        "down", -face:upvector,
        "left", -face:rightvector,
        "right", face:rightvector
    ).
    for key in nameToVec:keys {
        set split[key] to list().
    }
    
    for i in range(rcsList:length) {
        local rcsIter to rcsList[i].
        if rcsIter:thrustVectors:length = 1 {
            local thrust to rcsIter:thrustVectors[0].
            local name to "none".
            for key in nameToVec:keys {
                local vec to nameToVec[key].
                if vang(vec, -1 * thrust) < 5 {
                    set name to key.
                }
            }
            if name <> "none" {
                split[name]:add(i).
                set translators[i] to true.
                if not(name = "fore" or name = "aft") {
                    set rotators[i] to true.
                }
            }
        }
    }

    function distanceAlongFacing {
        parameter rcsInd.
        local rcsIter to rcsList[rcsInd].
        return vdot(rcsIter:position, face:forevector).
    }

    for key in nameToVec:keys {
        set split[key] to opsListSorted(split[key],
            opsCompareFromValue(distanceAlongFacing@)).
    }

    local ratios to shipRcsModeARatios(rcsList, split, face).

    return lexicon(
        "ratios", ratios,
        "translators", translators,
        "rotators", rotators
    ).
}

function shipRcsModeBRatios {
    parameter rcsList, split, face.
    // Configuration B is 6 5x thrusters, pair each at fore, mid, and aft.
    // They are indexed so that 0,1/2,3/4,5 have the same z axis
    // Can balance between the midpoint of 0,2 and 2,4.

    local ratios to opsListGenerate(0, rcsList:length).
    local faceVec to face:forevector.

    local lineRatios to shipRcsModeALineRatios(
        vdot(rcsList[split[0]]:position, faceVec),
        vdot(rcsList[split[2]]:position, faceVec),
        vdot(rcsList[split[4]]:position, faceVec)
    ).
    set ratios[split[0]] to lineRatios[0].
    set ratios[split[1]] to lineRatios[0].
    set ratios[split[2]] to lineRatios[1].
    set ratios[split[3]] to lineRatios[1].
    set ratios[split[4]] to lineRatios[2].
    set ratios[split[5]] to lineRatios[2].

    return ratios.
}

function shipRcsModeBEnumerate {
    parameter rcsList, face.

    local translators to opsListGenerate(false, rcsList:length).
    local rotators to opsListGenerate(false, rcsList:length).
    local split to list().

    
    for i in range(rcsList:length) {
        local rcsIter to rcsList[i].
        if rcsIter:thrustVectors:length = 5 {
            set translators[i] to true.
            set rotators[i] to true.
            split:add(i).
        }
    }

    function distanceAlongFacing {
        parameter rcsInd.
        local rcsIter to rcsList[rcsInd].
        return vdot(rcsIter:position, face:forevector).
    }

    set split to opsListSorted(split,
        opsCompareFromValue(distanceAlongFacing@)).

    local ratios to shipRcsModeBRatios(rcsList, split, face).

    return lexicon(
        "ratios", ratios,
        "translators", translators,
        "rotators", rotators
    ).
}


function shipRcsApplyMode {
    parameter rcsList, mode.

    for i in range(rcsList:length) {
        local rcsIter to rcsList[i].
        set rcsIter:thrustLimit to 100 * mode:ratios[i].
        local translates to mode:translators[i].
        set rcsIter:foreEnabled to translates.
        set rcsIter:topEnabled to translates.
        set rcsIter:starboardEnabled to translates.
        local rotates to mode:rotators[i].
        set rcsIter:rollEnabled to rotates.
        set rcsIter:yawEnabled to rotates.
        set rcsIter:pitchEnabled to rotates.
    }
}