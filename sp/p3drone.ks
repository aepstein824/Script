@LAZYGLOBAL OFF.

clearscreen.
runOncePath("0:common/operations.ks").
runOncePath("0:common/phasing.ks").
runOncePath("0:maneuvers/climb.ks").
runOncePath("0:maneuvers/hop.ks").
runOncePath("0:maneuvers/lambert.ks").
runOncePath("0:maneuvers/node.ks").
runOncePath("0:maneuvers/orbit.ks").
runOncePath("0:phases/dockrecv.ks").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit.ks").
runOncePath("0:phases/travel.ks").
runOncePath("0:phases/rndv.ks").
runOncePath("0:phases/waypoints.ks").

// Mission parameters
set kAirline:Vtol to true.
set kAirline:FinalS to 60.
set kAirline:HoverP:minAGL to 30.
set kAirline:HoverP:favAAT to 30.
set kAirline:FlightP:cruiseV to 100.
set kAirline:cruiseAlti to 7000.
local baseName to "Laythe Base".

if core:part:tag = "base" {
    set kClimb:Turn to 3.
    set kClimb:VertV to 100.
    set kClimb:SteerV to 200.
    set kClimb:ClimbAp to 100000.
    set kClimb:ClimbPe to 95000.
    set kClimb:Heading to 180.
    set kClimb:TLimAlt to 10000.
    set kClimb:OrbitStage to 1.

    climbInit().
    until climbSuccess() {
        climbLoop().
    }
    climbCleanup().
} else {
    local lzGeos to p3droneGeos().

    clearAll().
    flightSetSteeringManager().
    flightCreateReport(kAirline:FlightP).

    for lzGeo in lzGeos {
        local flatGeo to geoNearestFlat(lzGeo).
        local wptHdg to posAng(180 + geoHeadingTo(flatGeo, geoPosition)).
        local wpt to airlineWptCreate(flatGeo, wptHdg).

        opsUndockPart(core:part).
        wait 3.
        shipControlFromCommand().
        for e in ship:engines {
            if not e:ignition {
                e:activate.
            }
        }
        set kuniverse:activevessel to ship.

        // destination
        set kAirline:VlSpd to -2.
        airlineTo(wpt).
        wait 5.
        when shipIsLandOrSplash() then {
            doUseOnceScience().
            when groundAlt() > 10 then {
                doUseOnceScience(). 
            }
        }
        wait 5.

        local baseWpt to airlineWptFromVesselName(baseName).
        set kAirline:VlSpd to -0.5.
        airlineTo(baseWpt).
        wait until procCount() > 1.
        print "Docked".
        opsCollectRestoreScience().
        opsRefuel().
        wait 3.
    }
}

function p3droneGeos {
    local landingGeos to list(
        laythe:geopositionlatlng(15.8,    -65), // crater island
        laythe:geopositionlatlng(  28,    -66), // crater bay
        laythe:geopositionlatlng(  35,  159.5), // crescent bay
        laythe:geopositionlatlng(46.34, -124.833), // peaks
        laythe:geopositionlatlng(  52,     14), // degrasse sea
        laythe:geopositionlatlng(  73,     40), // shores
        laythe:geopositionlatlng(  75,     38), // shallows
        laythe:geopositionlatlng(  76,  -15.5), // dunes
        laythe:geopositionlatlng(  77,     25)  // sagen
    ).

    return landingGeos.
}