@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

function geoNorthFrame {
    parameter lzGeo.

    // This method is slower than using unitY as north, but may be more stable
    // close to the poles. It would also work on planets with tilt.
    local bod to lzGeo:body.
    local bodPos to bod:position.
    local lng to lzGeo:lng.
    local outVec to (lzGeo:position - bodPos):normalized.
    local geoNp to bod:geoPositionLatLng(90, lng).
    local toNp to geoNp:position - lzGeo:position.
    local northVec to vxcl(outVec, toNp):normalized.

    return lookDirUp(northVec, outVec).
}

function geoNorth2dToGeo {
    parameter geo, northFrame, pos2d.

    local bod to geo:body.
    local norm2d to vcrs(pos2d, unitY).
    local normRaw to northFrame * norm2d.
    local rotateRad to pos2d:mag / bod:radius.
    local outPos to rotateVecAroundR(geo:position - bod:position, normRaw,
        rotateRad).
    local outGeo to bod:geopositionof(outPos + bod:position).

    return outGeo.
}

function geoApproach {
    parameter lzgeo, head, dist.

    local lzFrame to geoNorthFrame(lzgeo).
    local approach to rotateVecAround(dist * unitZ, unitY, -1 * head).
    local approachGeo to geoNorth2dToGeo(lzgeo, lzFrame, approach).
    return approachGeo.
}

function geoBodyPosDistance {
    parameter posA, posB, bod to body.
    return bod:radius * vectorAngleR(
        posA - bod:position,
        posB - bod:position
    ).
}

function geoHeadingTo {
    parameter geoFrom, geoTo.

    local dp to geoTo:position - geoFrom:position.
    local northFrame to geoNorthFrame(geoFrom).
    local nfdp to northFrame:inverse * dp.
    local hdg to -1 * vectorAngleAround(unitZ, unitY, nfdp).
    return posAng(hdg).
}

function geoBeacon {
    parameter geoFrom, hdg.

    // I'm calling a beacon a 1/4 away around the planet. A beacon is a better
    // way to share directions between nearby geocoords when those coords are
    // around a pole.
    local bod to geoFrom:body.
    local northFrame to geoNorthFrame(geoFrom).
    local hdgVec to v(sin(hdg), 0, cos(hdg)).
    local around90 to bod:radius * constant:pi / 2.
    return geoNorth2dToGeo(geoFrom, northFrame, around90 * hdgVec).
}

function turn2d {
    parameter p, rad, d.
    // These circles also have a direction. Positive Y represents a ccw turn.
    // At p + rad * d:right, we're facing d:fore going around the circle.
    return lexicon("p", noY(p), "rad", rad, "d", d).
}

function turnCCW {
    parameter turn.
    return vdot(turn:d:upvector, unitY) > 0.
}

function noY {
    parameter vec.
    return v(vec:x, 0, vec:z).
}

function turnsIntersect {
    parameter a, b.
    return (a:p - b:p):mag >= (abs(a:rad) + abs(b:rad)).
}

function turnFromPoint {
    parameter pos, dir, rad, side.

    local cpos to pos + side * rad * dir:rightvector.
    // Still points in the final direction, but the right side dir is upsidedown
    // to represent the opposite rotation. Remember, LH coordinates, RH turns.
    local sgnDir to dir * R(0, 0, 90 + 90 * side).
    return turn2d(cpos, rad, sgnDir).
}

function turnOut {
    parameter turn.
    return turn:p + turn:rad * turn:d:rightvector.
}

function turnIntersectVec {
    // Vec must be in the same coordinates as circle:d.
    parameter circle, vec.
    return circle:p + circle:rad * vcrs(circle:d:upvector, vec:normalized).
}

function turnIntersectPoint {
    // P must be in same coordinates as circle:p.
    parameter circle, p.
    local toCirc to circle:p - p.
    local theta to arcSin(circle:rad / toCirc:mag).
    local intersect to p + rotateVecAround(
        cos(theta) * toCirc, 
        -circle:d:upvector,
        theta).
    return intersect.
}

function turnPointToPoint {
    parameter startPos, startRad, startDir.
    parameter endPos, endRad, endDir.
    local pathes to list().
    for s in list(-1, 1) {
        for e in list(-1, 1) {
            local startTurn to turnFromPoint(startPos, startDir, startRad, s).
            local endTurn to turnFromPoint(endPos, endDir, endRad, e).
            // print "Turn " + e.
            // print turnOut(endTurn).
            // print endTurn.
            // print endTurn:d:rightvector.
            // print "---".
            local pathCandidate to turnToTurn(startTurn, endTurn).
            if not pathCandidate:empty() {
                pathes:add(pathCandidate).

            }
            if s = e {
                local cc to turnToTurnCC(startTurn, endTurn).
                if not cc:empty() {
                    pathes:add(cc).
                }
            }
        }
    }
    local bestPath to list().
    local bestDistance to 100000000.
    for p in pathes {
        local distance to turnPathDistance(p).
        if distance < bestDistance {
            set bestDistance to distance.
            set bestPath to p.
        }
    }
    return bestPath.
}

function turnToTurn {
    parameter src, dst.
    local outPath to list(list("start", turnOut(src))).
    local between to dst:p - src:p. 
    local mag to between:mag.
    local upDot to vdot(src:d:upvector, dst:d:upvector).
    if upDot < 0 and mag < (src:rad + dst:rad) {
            return list().
        }
    local rDiff to upDot * dst:rad - src:rad.
    local cosTheta to rDiff / mag.
    if abs(cosTheta) > 1 {
        return list().
    }
    local upV to src:d:upvector.
    local theta to arcCos(cosTheta).
    local ndir to rotateVecAround(between, upV, theta):normalized.
    local srcOut to src:p - src:rad * ndir.
    local dstIn to dst:p - upDot * dst:rad * ndir.

    outPath:add(list("turn", srcOut, src)).
    outPath:add(list("straight", dstIn)).
    outPath:add(list("turn", turnOut(dst), dst)).
    return outPath.
}

function turnToTurnCC {
    parameter src, dst.
    local outPath to list(list("start", turnOut(src))).
    local between to dst:p - src:p. 
    local mag to between:mag.    
    local r1 to src:rad.
    local r2 to dst:rad.
    local r3 to (r1 + r2) / 2.
    if mag > (r1 + r2 + 2 * r3) {
        return list().
    }
    // simplifies to 2(r2-r1)(r2+r1) unless I change the r3 calculation
    local cosTnum to (mag^2) - (r2^2 - r1^2 + 2 * r3 * (r2 - r1)).
    local cosTden to 2 * (r1 + r3) * mag.
    local cosT to cosTnum / cosTden.
    local theta to arccos(cosT).
    local upV to src:d:upvector.
    local srcToMid to rotateVecAround(between, upV, theta):normalized.
    local srcOut to src:p + srcToMid * r1.
    local middleP to src:p + srcToMid * (r1 + r3).
    // middle turn must be opposite of other two
    local middleDir to lookDirUp(srcToMid, -upV).
    local mturn to turn2d(middleP, r3, middleDir).
    local dstIn to middleP + r3 * (dst:p - middleP) / (r2 + r3).
    outPath:add(list("turn", srcOut, src)).
    outPath:add(list("turn", dstIn, mTurn)).
    outPath:add(list("turn", turnOut(dst), dst)).
    return outPath.
}

function turnPathDistance {
    parameter inPath.

    local dist to 0.
    local prevP to inPath[0][1].
    for next in inPath:sublist(1, inPath:length() - 1) {
        local nextP to next[1].
        local x to (nextP - prevP).
        if next[0] = "straight" {
            set dist to dist + x:mag.
        }
        if next[0] = "turn" {
            local turn to next[2].
            local p1 to prevP - turn:p.
            local p2 to nextP - turn:p.
            local thetaR to vectorAngleAroundR(p1, turn:d:upvector, p2).
            set dist to dist + turn:rad * thetaR.
        }
        set prevP to nextP.
    }

    return dist.
}

function geoRound {
    parameter geo, n to 4.
    local bod to geo:body.
    return bod:geopositionlatlng(round(geo:lat, n), round(geo:lng, n)).
}

function geoRoundStr {
    parameter geo, n to 4.
    local bod to geo:body.
    return bod:name + ":(" + round(geo:lat, n) + ", " + round(geo:lng, n) + ")".
}

function shipVHeading {
    local frame to geoNorthFrame(geoPosition).
    local vel to velocity:surface.
    local frameVel to noy(frame:inverse * vel).
    local hdg to vectorAngleAround(frameVel, unitY, unitZ).
    return hdg.
}
