@LAZYGLOBAL OFF.

clearscreen.

runOncePath("0:common/geo").
runOncePath("0:common/ship").
runOncePath("0:phases/airline").

set kAirline:Vtol to (vang(facing:forevector, up:forevector) < 30).

clearAll().
airlineInit().

// airlineTo(kAirline:Wpts:NP27).
// airlineTo(kAirline:Wpts:Dessert18).
// airlineTo(kAirline:Wpts:Island09).
set kAirline:VlSpd to -0.5.
airlineTo(airlineWptFromVesselName("Laythe Base")).

// airlineTo(kAirline:Wpts:Ksc09).

// if false {
//     local loopA to airlineWptFromWaypoint(waypoint("ksc 09"), 270, 1000).
//     local loopB to airlineWptFromWaypoint(waypoint("ksc 27"), 90, 1000).
//     print "Begin loop A".
//     airlineLoop(loopA).
//     print "Begin loop B".
//     airlineLoop(loopB).
// }