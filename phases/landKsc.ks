@LAZYGLOBAL OFF.

runPath("0:common/control.ks").
runPath("0:maneuvers/landAtm.ks").
runOncePath("0:phases/airline.ks").

local kKerbPark to 75000.
local kLandingBudget to 200.
global kLandingPe to 0.
global kQToAoa to 900.
global kReturnTanly to 120.

function preventEscape {
    controlLock().
    if obt:transition = "ESCAPE" {
        print "Avoiding escape!".
        set controlSteer to ship:retrograde.
        wait 1.
        set controlThrot to 1.
        wait until obt:transition = "FINAL".
        set controlThrot to 0.
        wait 1.
    }
    controlUnlock().
}

function circleAtKerbin {

    preventEscape().

    changePeAtAp(kKerbPark).
    if orbitPatchesInclude(nextNode:orbit, mun) {
        set nextNode:eta to nextNode:eta + orbit:period.
    }
    nodeExecute().

    changeApAtPe(kKerbPark).
    local dvBudget to ship:deltav:current - kLandingBudget.
    set nextNode:prograde to clampAbs(nextNode:prograde, dvBudget).
    nodeExecute().

    if periapsis < kKerbPark {
        changePeAtAp(kKerbPark).
        nodeExecute().
    }
}

function landKsc {
    planLandingBurn().
    nodeExecute().
    landFromDeorbit().
}

local function dynamicPres {
    parameter alti, spd.
    return 0.5 * body:atm:altitudepressure(alti) * (spd ^ 2).
}

function landPlaneDeorbit {
    print "Planning deorbit".
    // land in the daytime
    opsWarpTillSunAngle(waypoint("ksc"), 270).
    wait 5.
    set kLandAtm:ReturnTanly to kReturnTanly.
    set kLandAtm:EntryPe to kLandingPe.
    planLandingBurn().
    nodeExecute().
    print " End burn at " + geoRound(geoPosition).
    lock steering to shipNorm().
    wait 5.
    unlock steering.
    stageTo(0).
    wait 1.

    getToAtm().
}

function landPlaneReentry {
    print "Reentry".

    set kuniverse:timewarp:mode to "PHYSICS".
    set kuniverse:timewarp:rate to 2. 

    controlLock().
    
    set controlThrot to 0.
    local aoa to 90.

    until altitude < 20000 or airspeed < 700 {
        local dyn to dynamicPres(altitude, airspeed).
        if dyn > 30000 {
            set aoa to 2.
        } else {
            // emperically measured formula in stock
            set aoa to kQToAoa / sqrt(max(dyn, 1)).
            set aoa to clamp(aoa, 2, 90).
        }

        set controlSteer to srfPrograde * r(-aoa, 0, 0).
        wait 0.
    }
}

function landPlaneRunway {
    print " Begin flight at " + geoRound(geoPosition).
    set kAirline:Vtol to false.
    set kAirline:FinalS to 200.
    set kAirline:VspdAng to 20.

    local landWpt to airlineWptFromWaypoint(waypoint("ksc 09"), 90).
    local approachWpt to airlineWptApproach(landWpt).

    airlineInit().
    airlineSwitchToFlight().

    local flightP to kAirline:FlightP.
    set flightP:descentV to -1.3. // plenty of runway
    set flightP:maneuverV to 100.
    set flightP:cruiseV to 250.

    airlineCruise(approachWpt, false).

    print " Finished cruise "+ geoRound(geoPosition).
    airlineShortHaul(approachWpt).

    kuniverse:timewarp:cancelwarp().

    print " Loop to runway". 
    airlineLoop(approachWpt).
    print " Begin landing".
    airlineLanding(landWpt).
}