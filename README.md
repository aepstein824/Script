# Welcome

This is my set of scripts for automating the rockets and planes in Kerbal Space Program, using kOS.

# What it can do

Contained within is code for these operations

## Orbits
* Change an orbit's ap, pe, inc.
* Intersect another orbit, be it a body or craft.
    * For bodies, capture into an orbit with arbitrary inclination.
    * For crafts, rendezvouz and dock.
* Travel from any orbit to a specified orbit around another body.
    * Employs a lambert solver using hohmann transfers as an initial guess.
    * Calculates orbits with arbitrary escape trajectories.
    * Single burn to transfer from one moon to another.

## To and From Ground
* Fly a plane.
    * Takeoff.
    * Landing following a glide slope with a flare.
    * Calculate and follow waypoints based on air speed.
    * In some situations, estimate plane's stall speed.
    * Fly a plane from runway to runway across the planet.
* Fly a hover craft.
    * Hover a craft at a given height above obstacles.
    * Can fly toward a target, calculating necessary stopping speed.
    * Can land precisely on a target.
* Launch a rocket to orbit.
    * Follows prograde after an initial steering phase.
    * Pitches to counter gravity to avoid raising ap with low TWR engines.
    * Can launch into an arbitrary inclination or target's orbit.
* Land a rocket.
    * Deorbit and suicide burns get within 200m of the target.
    * Putting the rocket in hover mode can land precisely on a target for 200dv.
    * Propulsive landings in atmosphere.
* Land a space plane from orbit to runway.

# About the Code

## Organization
The files are organized in layers by directory. The layers from lowest to highest are common, maneuvers, phases, missions/sp. I haven't been strict about dependencies within layers. Generally, the common directory contains utility functions. The maneuvers directory contains isolated, atomic tasks. The phases directory contains code which composes maneuvers into multi step complex tasks. Each mission is a sequence of phases that covers a craft launching from the pad, doing what needs to be done, and then ending up in a resting state on either the ground or some parking orbit (eg communications satellite).

## Handedness
My greatest regret is that this code uses right hand angles in a left hand coordinate system. All of the vector spaces are left handed like they are in KSP, but all calculated rotations are right handed. This mistake originated when I implemented the lambert solver following a paper that used right handed calculations. I figured, "Kerbin rotates right handedly, so that's probably the best system to use". As obnoxious as keeping the signs straight can be here, I will say it's really convenient to be able to do a coordinate system left hand rule gesture and a thumb curl right hand gesture at the same time.