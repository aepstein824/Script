// function hoverHAccLinear {
//     parameter params.

//     if abs(verticalSpeed) > params:maxSpdV {
//         return zeroV.
//     }

//     local travel to params:travel.
//     local travelInv to travel:inverse.
//     local curAWorld to params:prevA.
//     local curA to travelInv * curAWorld.
//     local toTgt to travelInv * params:tgt:position.
//     local travelV to travelInv * velocity:surface.
//     local moveJerk to params:jerkH.
//     local limitJerk to moveJerk.
//     if params:mode <> kHover:Hover {
//         set limitJerk to moveJerk / 2.
//     }
//     set curA:z to 0.
//     set toTgt:z to 0.
//     set travelV:z to 0.

//     // The promise refers to the velocity that our acceleration will grant us
//     // before we can bring the acceleration vector back to 0. Because of the
//     // constant jerk assumption, it can be calculated exactly.

//     // Velocity promised from current acceleration
//     local promisedDV to curA * curA:mag / limitJerk / 2.
//     // Final velocity when back to 0.
//     local promisedV to travelV + promisedDV.
//     // The desiredV is the amount we expect to be able to zero out by the time
//     // we reach the target.
//     local desiredV to v(0, 0, 0).
//     if params:seek {
//         local spd2 to toTgt:y * limitJerk - curA:y.
//         local spd to sgnSqrt(spd2 / 2).
//         set desiredV:y to clamp(spd, -params:maxSpdH, params:maxSpdH).
//     }

//     local desiredA to desiredV - promisedV.
//     local errorA to desiredA - curA.
//     local timeDiff to max(time:seconds - params:prevTime, 0.001).
//     // Accel can only be changed by an amount within the jerk limit.
//     local deltaA to vecClampMag(errorA, moveJerk * timeDiff).
//     local newA to curA + deltaA.

//     set newA to vecClampMag(newA, params:maxAccelH * gat(altitude)).
//     set params:prevTime to time:seconds.
//     local worldA to travel * newA.
//     set params:prevA to worldA.

//     // print "promisedV " + vecRound(promisedV, 2)
//     //     + " desiredV " + vecRound(desiredV, 2)
//     //     + " desiredA " + vecRound(desiredA, 2)
//     //     + " towards " + vecround(toTgt, 2).

//     return worldA.
// }
