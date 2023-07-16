@LAZYGLOBAL OFF.

clearscreen.

runOncePath("0:common/geo").
runOncePath("0:common/phasing.ks").
runOncePath("0:common/ship").
runOncePath("0:phases/airline").
runOncePath("0:phases/landKsc.ks").
runOncePath("0:phases/launchToOrbit").

// Testing
set kPhases:startInc to 0.
set kPhases:stopInc to 4.
// set kPhases:phase to 0.

global kSsto to lex().
set kSsto:LowAlti to 2000.
set kSsto:LowSpd to 100.
set kSsto:HighAlti to 4500.
set kSsto:HighSpd to 500.
set kSsto:HighLevelTan to tan(5).
set kSsto:HighClimbTan to tan(45).
set kSsto:HighVPlus to 15.
set kSsto:SpaceAlti to 16000.
// writeJson(kSsto, opsDataPath("kSsto")). print 1/0.
opsDataLoad(kSsto, "kSsto"). 
set kSsto:StateLow to "LOW".
set kSsto:StateHigh to "HIGH".
set kSsto:StateHighClimb to "HIGHCLIMB".
set kSsto:StateSpace to "SPACE".
set kSsto:Runway to kAirline:Wpts:Ksc09.

set kAirline:Vtol to (vang(facing:forevector, up:forevector) < 30).

clearAll().
airlineInit().

if shouldPhase(0) {
    set kAirline:TakeoffHeading to 90.
    // Should be a eastern beacon?
    airlineTakeoff(kAirline:Wpts:Ksc27).
    local sstoFlightP to kAirline:FlightP.
    set kuniverse:timewarp:mode to "PHYSICS".
    print "Ssto low level".
    set kuniverse:timewarp:rate to 2.
    sstoLowLevel(sstoFlightP).
    print "Ssto low climb".
    set kuniverse:timewarp:rate to 4.
    sstoLowClimb(sstoFlightP).
    print "Ssto high level".
    sstoHighLevel(sstoFlightP).
    set kuniverse:timewarp:rate to 2.
    print "Ssto high climb".
    sstoHighClimb(sstoFlightP).

    steeringManager:resettodefault().
    launchToOrbit().
}
if shouldPhase(1) {
    rcs on.
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

        set flightP:hspd to groundspeed + 50.

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

        set flightP:hspd to groundspeed + 50.

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
        if e:tag = "space" {
            if state = kSsto:StateHighClimb or state = kSsto:StateSpace {
                e:activate().
            } else {
                e:shutdown().
            }
        } else if e:tag = "wetdry" {
            if state = kSsto:StateLow {
                e:activate().
                if not e:primarymode {
                    e:togglemode().
                }
            } else if state = kSsto:StateHigh or state = kSsto:StateHighClimb {
                e:activate().
                if e:primarymode {
                    e:togglemode().
                }
            } else if state = kSsto:StateSpace {
                print "shutting down space engines?!".
                e:shutdown().
            }
        } else if e:tag = "jet" {
            if state = kSsto:StateLow {
                e:activate().
            } else if state = kSsto:StateSpace {
                e:shutdown().
            }
        }
    }
    wait 0.
}