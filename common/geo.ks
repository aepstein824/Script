@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

function geoNorthFrame {
    parameter lzgeo.

    local out to (lzgeo:position - body:position).
    local localNorth to removeComp(unitY, out).

    return lookDirUp(localNorth, out).
} 

function geoApproach {
    parameter lzgeo, head, dist.

    local lzFrame to geoNorthFrame(lzgeo).
    local approach to rotateVecAround(dist * unitZ, unitY, -1 * head).
    local pos to lzFrame * approach + lzgeo:position.
    return body:geoPositionof(pos).
}

function turn2d {
    parameter p, r, d.
    // These circles also have a direction. Positive Y represents a ccw turn.
    // At p + r * d:right, we're facing d:fore going around the circle.
    return lexicon("p", noY(p), "r", r, "d", d).
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
    return (a:p - b:p):mag >= (abs(a:r) + abs(b:r)).
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
    return turn:p + turn:r * turn:d:rightvector.
}

function turnIntersectVec {
    // Vec must be in the same coordinates as circle:d.
    parameter circle, vec.
    return circle:p + circle:r * vcrs(circle:d:upvector, vec:normalized).
}

function turnIntersectPoint {
    // P must be in same coordinates as circle:p.
    parameter circle, p.
    local toCirc to circle:p - p.
    local theta to arcSin(circle:r / toCirc:mag).
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
            local path to turnToTurn(startTurn, endTurn).
            if not path:empty() {
                pathes:add(path).

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
    local path to list(list("start", turnOut(src))).
    local between to dst:p - src:p. 
    local mag to between:mag.
    local upDot to vdot(src:d:upvector, dst:d:upvector).
    if upDot < 0 and mag < (src:r + dst:r) {
        return list().
    }
    local rDiff to upDot * dst:r - src:r.
    local cosTheta to rDiff / mag.
    local upV to src:d:upvector.
    local theta to arcCos(cosTheta).
    local ndir to rotateVecAround(between, upV, theta):normalized.
    local srcOut to src:p - src:r * ndir.
    local dstIn to dst:p - upDot * dst:r * ndir.

    path:add(list("turn", srcOut, src)).
    path:add(list("straight", dstIn)).
    path:add(list("turn", turnOut(dst), dst)).
    return path.
}

function turnToTurnCC {
    parameter src, dst.
    local path to list(list("start", turnOut(src))).
    local between to dst:p - src:p. 
    local mag to between:mag.    
    local r1 to src:r.
    local r2 to dst:r.
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
    path:add(list("turn", srcOut, src)).
    path:add(list("turn", dstIn, mTurn)).
    path:add(list("turn", turnOut(dst), dst)).
    return path.
}

function turnPathDistance {
    parameter path.

    local dist to 0.
    local prevP to path[0][1].
    for next in path:sublist(1, path:length() - 1) {
        local nextP to next[1].
        local x to (nextP - prevP).
        if next[0] = "straight" {
            set dist to dist + x:mag.
        }
        if next[0] = "turn" {
            local turn to next[2].
            // A small fudge factor to make 180 degrees pass.
            local twoR2 to 2.0000001 * turn:r ^ 2.
            local thetaR to arcCosR((twoR2 - x:mag ^ 2) / twoR2).
            if vdot(x, turn:d:vector) < 0 {
                set thetaR to 2 * constant:pi - thetaR.
            }
            set dist to dist + turn:r * thetaR.
        }
        set prevP to nextP.
    }

    return dist.
}