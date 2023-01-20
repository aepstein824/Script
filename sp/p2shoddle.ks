@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/phasing.ks").
runOncePath("0:common/operations.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/landAtm.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/airline.ks").
runOncePath("0:phases/launchToOrbit.ks").

// Mission parameters
local landingPe to 0.
local qToAoa to 900.
local returnTanly to 120.

// Testing
set kPhases:startInc to 0.
set kPhases:stopInc to 4.
// set kPhases:phase to 4.

// Launch
set kClimb:VertV to 40.
set kClimb:SteerV to 150.
set kClimb:Turn to 9.

local function dynamicPres {
    parameter alti, spd.
    return 0.5 * body:atm:altitudepressure(alti) * (spd ^ 2).
}

clearAll().

if shouldPhase(0) {
    print "Launch to Orbit!".
    launchQuicksave("shoddle_launch").
    launchToOrbit().
    wait 3.
}
if shouldPhase(1) {
    print "Correcting circularization".
    circleNextExec(75000).
    wait 1.
}
if shouldPhase(2) {
    print "Planning deorbit".
    // land in the daytime
    opsWarpTillSunAngle(waypoint("ksc"), 270).
    wait 5.
    set kLandAtm:ReturnTanly to returnTanly.
    set kLandAtm:EntryPe to landingPe.
    planLandingBurn().
    nodeExecute().
    print " End burn at " + geoPosition.
    stageTo(0).
    wait 1.

    getToAtm().
}
if shouldPhase(3) {
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
            set aoa to qToAoa / sqrt(max(dyn, 1)).
            set aoa to clamp(aoa, 2, 90).
        }

        set controlSteer to srfPrograde * r(-aoa, 0, 0).
        wait 0.
    }
}
if shouldPhase(4) {
    print " Begin flight at " + geoPosition.
    set kAirline:Vtol to false.
    set kAirline:FinalS to 200.
    set kAirline:VspdAng to 20.

    airlineInit().
    airlineSwitchToFlight().

    local flightP to kAirline:FlightP.
    set flightP:maneuverV to 75.
    set flightP:cruiseV to 130.
    flightBeginLevel(flightP).
    local runway to kAirline:Runway.
    until false {
        local runwayPos to runway:position.
        local horiRunway to vxcl(up:forevector, runwayPos).
        local towards to lookDirUp(horiRunway, up:forevector).
        local runwayTowards to towards:inverse * runwayPos.

        local movingToRunway to vdot(velocity:surface, runwayPos) > 0.
        local closeToRunway to runwayTowards:z < 45000.
        if (closeToRunway or not movingToRunway) and altitude < 7500 {
            break.
        }
        local runwayAngle to arctan2(runwayTowards:y, runwayTowards:z).
        local descendAngle to max(abs(runwayAngle), 10).
        set flightP:vspd to airlineCruiseVspd(kAirline:CruiseAlt, 
            altitude, descendAngle).

        airlineIterWait().
    }

    kuniverse:timewarp:cancelwarp().

    print " Fly to runway from " + geoPosition.
    airlineLoop().
    airlineLanding().
}

