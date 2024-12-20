@LAZYGLOBAL OFF.


clearScreen.
runOncePath("0:common/geo").
runOncePath("0:common/phasing.ks").
runOncePath("0:common/ship").
runOncePath("0:phases/airline").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit").
clearAll().

// Testing
set kPhases:startInc to choose 2 if status = "ORBITING" else 0.
set kPhases:stopInc to 4.
// set kPhases:phase to 0.

global kSsto to lex().
set kSsto:LowAlti to 2000.
set kSsto:LowSpd to 500.
set kSsto:HighAlti to 7000.
set kSsto:HighSpd to 1200.
set kSsto:HighLevelTan to tan(5).
set kSsto:HighClimbTan to tan(45).
set kSsto:HighVPlus to 15.
set kSsto:SpaceAlti to 20000.
set kSsto:AirResource to "LiquidFuel".
set kSsto:SpaceResource to "Oxidizer".
set kSsto:PhysxWarpLimit to 3.
// writeJson(kSsto, opsDataPath("kSsto")). print 1/0.
opsDataLoad(kSsto, "kSsto"). 
set kSsto:StateTakeoff to "TAKEOFF".
set kSsto:StateLow to "LOW".
set kSsto:StateHigh to "HIGH".
set kSsto:StateHighClimb to "HIGHCLIMB".
set kSsto:StateSpace to "SPACE".
set kSsto:Runway to kAirline:Wpts:Ksc09.

set kAirline:Vtol to (vang(facing:forevector, up:forevector) < 30).

local airResource to ship:resources[0].
local spaceResource to ship:resources[0].
for i in range(ship:resources:length) {
    local res to ship:resources[i].
    if res:name = kSsto:AirResource {
        set airResource to ship:resources[i].
    }
    if res:name = kSsto:SpaceResource {
        set spaceResource to ship:resources[i].
    }
}
local airDensity to airResource:density.
local spaceDensity to spaceResource:density.

airlineInit().

if shouldPhase(0) {
    set kAirline:TakeoffHeading to 90.
    sstoEnginesFor(kSsto:StateTakeoff).
    // Should be a eastern beacon?
    airlineTakeoff(kAirline:Wpts:Ksc27).
    local airStart to airResource:amount.
    local sstoFlightP to kAirline:FlightP.
    set kuniverse:timewarp:mode to "PHYSICS".
    print "Ssto low level".
    set kuniverse:timewarp:rate to min(2, kSsto:PhysxWarpLimit).
    sstoLowLevel(sstoFlightP).
    print "Ssto low climb".
    set kuniverse:timewarp:rate to min(4, kSsto:PhysxWarpLimit).
    sstoLowClimb(sstoFlightP).
    local airPostLow to airResource:amount.
    print " Burned " + round(airDensity * (airStart - airPostLow), 2)
        + " " + airResource:name.
    print "Ssto high level".
    sstoHighLevel(sstoFlightP).
    local airPostHigh to airResource:amount.
    set kuniverse:timewarp:rate to min(2, kSsto:PhysxWarpLimit).
    print " Burned " + round(airDensity * (airPostLow - airPostHigh), 2)
        + " " + airResource:name.
    print "Ssto high turn".
    local spacePreTurn to spaceResource:amount.
    sstoHighClimb(sstoFlightP).
    local spacePostTurn to spaceResource:amount.
    print " Burned " + round(spaceDensity * (spacePreTurn - spacePostTurn), 2)
        + " " + spaceResource:name.
    print "Ssto space".

    steeringManager:resettodefault().
    launchToOrbit().
    local spacePostOrbit to spaceResource:amount.
    print " Burned " + round(spaceDensity * (spacePostTurn - spacePostOrbit), 2)
        + " " + spaceResource:name.
    wait 1.
}
if shouldPhase(1) {
    print "Correcting circularization".
    circleNextExec(75000).
    wait 1.
    pressAnyKey().
}
if shouldPhase(2) {
    landPlaneDeorbit(kSsto:Runway).
}
if shouldPhase(3) {
    disableRcs().
    landPlaneReentry().
}
if shouldPhase(4) {
    sstoEnginesFor(kSsto:StateLow).
    landPlaneRunway(kSsto:Runway).
}

function sstoLowLevel {
    parameter flightP.

    local turnXacc to airlineTurnXacc(gat(0)).

    sstoEnginesFor(kSsto:StateLow).
    flightBeginLevel(flightP).
    setFlaps(0).

    until false {
        set flightP:xacc to airlineBearingXacc(90 - shipVHeading(), turnXacc).

        set flightP:vspd to airlineCruiseVspd(kSsto:LowAlti, altitude,
            kAirline:VspdAng).

        set flightP:hspd to kSsto:LowSpd.

        airlineIterWait().

        if groundspeed > kSsto:LowSpd - 5 {
            return.
        }
    }
}

function sstoLowClimb {
    parameter flightP.

    local turnXacc to airlineTurnXacc(gat(0)).

    until false {
        set flightP:xacc to airlineBearingXacc(90 - shipVHeading(), turnXacc).

        set flightP:vspd to airlineCruiseVspd(kSsto:HighAlti, altitude,
            kAirline:VspdAng).

        set flightP:hspd to kSsto:LowSpd.

        airlineIterWait().

        if altitude > kSsto:HighAlti - 50 {
            return.
        }
    }
}

function sstoHighLevel {
    parameter flightP.

    local turnXacc to airlineTurnXacc(gat(0)).

    sstoEnginesFor(kSsto:StateHigh).

    until false {
        set flightP:xacc to airlineBearingXacc(90 - shipVHeading(), turnXacc).

        set flightP:vspd to min(groundspeed * kSsto:HighLevelTan,
            verticalspeed + kSsto:HighVPlus / 2).

        set flightP:hspd to groundspeed + 500.

        airlineIterWait().

        if groundspeed > kSsto:HighSpd - 1 {
            return.
        }
    }
}

function sstoHighClimb {
    parameter flightP.

    local turnXacc to airlineTurnXacc(gat(0)).

    sstoEnginesFor(kSsto:StateHighClimb).

    until false {
        set flightP:xacc to airlineBearingXacc(90 - shipVHeading(), turnXacc).

        set flightP:vspd to min(groundspeed * kSsto:HighClimbTan,
            verticalspeed + kSsto:HighVPlus).

        set flightP:hspd to groundspeed + 500.

        airlineIterWait().

        if altitude > kSsto:SpaceAlti - 10 {
            sstoEnginesFor(kSsto:StateSpace).
            return.
        }
    }
}

function sstoEnginesFor {
    parameter state.

    local engs to ship:engines.
    for e in engs {
        if e:tag = "takeoff" {
            if state = kSsto:StateTakeoff {
                e:activate().
            } else {
                e:shutdown().
            }
        } else if e:tag = "space" {
            if state = kSsto:StateHighClimb or state = kSsto:StateSpace {
                e:activate().
            } else {
                e:shutdown().
            }
        } else if e:tag = "wetdry" {
            if state = kSsto:StateLow or state = kSsto:StateTakeoff {
                e:activate().
                if not e:primarymode {
                    e:togglemode().
                }
            } else if state = kSsto:StateHigh or state = kSsto:StateHighClimb {
                e:activate().
                if e:primarymode {
                    e:togglemode().
                }
            } 
        } else if e:tag = "jet" {
            if state = kSsto:StateSpace {
                e:shutdown().
            } else {
                e:activate().
            }
        } else if e:tag = "openclose" {
            e:activate().
            if state = kSsto:StateSpace {
                if e:primarymode {
                    e:togglemode().
                }
            } else {
                if not e:primarymode {
                    e:togglemode().
                }

            }
        }
    }
    wait 0.
}