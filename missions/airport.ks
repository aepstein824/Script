@LAZYGLOBAL OFF.

clearscreen.

runOncePath("0:common/phasing.ks").
runOncePath("0:phases/airline").

set kPhases:startInc to 0.
set kPhases:stopInc to 0.

// set kAirline:Runway to waypoint("island 09").
set kAirline:Runway to waypoint("ksc 09").
// set kAirline:Runway to waypoint("ksc 27").
// set kAirline:Runway to waypoint("Cove Launch Site").
set kAirline:TakeoffHeading to 90.
set kAirline:LandHeading to 90.
// set kAirline:LandHeading to 270.

clearAll().

airlineInit().
airlineTakeoff().
airlineLoop().
airlineLanding().