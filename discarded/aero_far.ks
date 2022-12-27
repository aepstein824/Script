
function flightLevelAoAFar {
    parameter vspd, hspd, grav.

    local levV to v(0, vspd, hspd).
    // for now travel is a based on level
    local travel to lookDirUp(levV, unitY).
    local travelV to travel:inverse * levV.


    // Units of force, since aero doesn't care about mass
    local G to v(0, -1, 0) * grav * ship:mass.
    local presFactor to (far:ias / velocity:surface:mag) ^ 2.

    local aoa to 0.
    local aoaInc to 5.
    local A to v(0, 0, 0).
    local T to v(0, 0, 0).
    local i to 0.
    until false {
        local attackRot to flightPitch(aoa).
        local evalV to attackRot:inverse * travelV.

        local vSurf to facing * evalV.
        local facingAero to facing:inverse * far:aeroforceat(0, vSurf).
        // aeroforce at 0 
        set A to travel * attackRot * facingAero.
        set A to A * presFactor.
        set A:x to 0. // assume no side force
        set T to -1 * (A + G).

        local tAoa to vectorAngleAround(unitZ, unitX, T).
        if tAoa > 180 {
            set tAoa to tAoa - 360.
        }
        // print "aoa: " + round(aoa, 3) + " tAoa: " + round(tAoa, 3).
        local diff to tAoa - aoa.
        if abs(diff) < 0.5 or i > 15 {
            // print "setting aoa to " + round(aoa, 3).
            // set flight to level * rolled * attackRot.
            break.
        } else if diff > 0 {
            set aoa to aoa + aoaInc.
        } else {
            set aoa to aoa - aoaInc.
        }
        set aoaInc to aoaInc * 0.5.
        set i to i + 1.
    }

    return v(aoa, T:mag, 0).
}

// Document the process of calculating aero effects at current situation.
// Without FAR providing IAS, we would need temp and pres sensors to get the
// same values.
function flightCalcLevel {
    local out to -body:position.
    local lev to removeComp(facing:forevector, out).
    local level to lookDirUp(lev, out).
    local vSurf to velocity:surface.

    local vRaw to vSurf.

    local A to level:inverse * far:aeroforceat(0, vRaw).
    local Alevel to level:inverse * far:aeroforce.

    local atm to body:atm.

    local tas to vSurf:mag.
    local gamma to atm:adbidx.
    local staticPres to ship:sensors:pres * 1000.
    local temp to ship:sensors:temp.
    // rho is mass density = number density * molar mass
    // number density = p / RT
    local numberDensity to staticPres / constant:IdealGas / temp.
    local molarMass to atm:molarmass.
    local rho to numberDensity * molarMass.
    // a = sart(gamma * p / rho)
    local soundSpd to sqrt(gamma * staticPres / rho).
    local mach to tas / soundSpd.
    // q = M^2 * (1/2) * gamma * p
    // factor of 1000 to convert back to kpa
    local q to (mach ^ 2) * 0.5 * gamma * staticPres / 1000.
    // alternatively, q = 0.5 * rho * u^2
    local qq to 0.5 * rho * tas ^ 2 / 1000.

    local ias to tas / sqrt(1.225 / rho).

    local avgTemp to atm:altitudetemperature(0).
    local avgPres to atm:altitudepressure(0) * 1000 * constant:atmtokpa.
    local qFactor to (temp / avgTemp) ^ (-1) * (staticPres / avgPres).

    local ias_rat to tas / far:ias.
    local ias_qrat to ias_rat ^ 2.
    local ias_A to A / ias_qrat.

    clearall().
    print "speed of sound = " + soundSpd.
    print "rho = " + rho.
    print "avgTemp = " + avgTemp.
    print "avgPres = " + avgPres.
    print "q factor = " + qFactor.
    print "---".
    print "Alevel " + vecRound(Alevel, 2).
    print "Asense " + vecRound(A * qFactor, 2).
    print "A ias  " + vecRound(ias_A, 2).
    print "---".
    print "Guess Q " + q.
    print "Other Q " + qq.
    print "Check Q " + far:dynpres.
    print "---".
    print "Guess mach " + mach.
    print "Check mach " + far:mach.
    print "---".
    print "Guess IAS " + ias.
    print "Check IAS " + far:ias.

}
