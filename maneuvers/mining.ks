@LAZYGLOBAL OFF.

global kMining to Lexicon().
set kMining:astRemainder to 1.

function mineAsteroid {
    // find asteroid part, watch mass
    local allResources to list().
    list resources in allResources.
    local foundOre to false.
    local ore to false.
    for r in allResources {
        if r:name = "ORE" {
            set ore to r.
            set foundOre to true.
        }
    }
    if foundOre = false {
        print "No ore tanks.".
        return.
    }

    local allparts to list().
    list parts in allparts.
    local roids to list().
    for p in allparts {
        if p:hasmodule("ModuleAsteroid") {
            roids:add(p).
        }
    }
    if roids:length <> 1 {
        print "Wrong number of asteroids?! " + roids.
        return.
    }
    local asteroid to roids[0].

    drills on. 
    isru on.

    until asteroid:mass < kMining:astRemainder {
        print asteroid:mass.
        wait 0.
    }
    drills off.
}