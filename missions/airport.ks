@LAZYGLOBAL OFF.

clearscreen.

runOncePath("0:common/geo").
runOncePath("0:common/ship").
runOncePath("0:phases/airline").

clearAll().

airportTo(kAirline:Wpts:Dessert18).
airportTo(kAirline:Wpts:Ksc09).

function airportTo {
    parameter landWpt.
    local approachWpt to airlineWptApproach(landWpt).
    local approachGeo to approachWpt:geo.

    set kAirline:TakeoffHeading to shipHeading().
    airlineInit().
    airlineTakeoff().

    set kuniverse:timewarp:rate to 4.

    if geoBodyPosDistance(zeroV, approachGeo:position) > kAirline:CruiseDist {
        local departWpt to airlineWptCreate(geoPosition, approachWpt:geo:heading,
            kAirline:CruiseAlti).

        print "Turn to depart from current location".
        airlineLoop(departWpt).
        print "Cruise to destination".
        airlineCruise(approachWpt).
    }

    set kuniverse:timewarp:rate to 3.

    if geoBodyPosDistance(zeroV, approachGeo:position) > kAirline:FlatDist {
        print "Short distance to approach".
        airlineShortHaul(approachWpt).
    }

    set kuniverse:timewarp:rate to 2.

    print "Go to approach".
    airlineLoop(approachWpt).
    print "Begin landing".
    airlineLanding(landWpt).
}

// if false {
//     local loopA to airlineWptFromWaypoint(waypoint("ksc 09"), 270, 1000).
//     local loopB to airlineWptFromWaypoint(waypoint("ksc 27"), 90, 1000).
//     print "Begin loop A".
//     airlineLoop(loopA).
//     print "Begin loop B".
//     airlineLoop(loopB).
// }