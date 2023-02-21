# A Plane Autopilot for KSP
In which I describe a system for flying programmitically in KSP.

The attached `flightdata.dot` is a graphviz diagram which describes the dataflow.

# Goal of the Flight Controller
The flight controller maintains a desired vertical speed, horizontal speed, and turning acceleration.

It's output is a steering vector and throttle setting. KOS cooked steering turns the steering vector into roll, pitch, and yaw commands.

# Modeling the Lift and Drag Equations
This section explains `flightModelUpdate`.

`Lift = Q * S * Cl * aoa`
`Drag = Q * S * Cd * aoa`

These equations will allow us to choose an angle of attack (aoa) for desired lift, and then calculate the drag at that aoa.

In kOS, Q is directly available at `ship:dynamicpressure`. Our current aoa can be easily calculated from the `facing` and `srfPrograde` directions. We need to calculate `S * Cl`. Since `S`, the wing reference area, is a constant, let's just fold it in and call them both Cl from now on.

To estimate Cl and Cd, we need some data about lift and drag at various angles of attack. To track the forces, first we track the acceleration of the plane as the derivative of `velocity:surface`. The difference between the values each tick / the time between the ticks yields the acceleration. Then we can subtract out the accelerations we know of. Gravity in the direction towards the body and thrust in the facing direction. What's left is the acceleration due to aerodynamic forces. The component in the direction of the velocity is drag, the component in the direction 90 towards our facing:upvector is the lift. Once we have our lift, drag, and aoa data points, we can use linear regression to estimate Cl and Cd. The formulas for [Simple Linear Regression](https://en.wikipedia.org/wiki/Simple_linear_regression) can be easily calculated online for each incoming data point. We maintain a queue of the most recent 100 points (a few seconds) to build the model. 

# Choosing Desired Accelerations
This section covers `flightLevel`.

We need to turn the targets into accelerations. For horizontal and vertical speed targets, we use PID controllers.

The PID controllers have a proportional gain of 1 and Kd/Ki terms at 0.2. 

I have not tuned them. In theory, tuning the Kd/Ki terms could tighten up stabilizing at a desired speed, but I don't have any missions that require that.

A gain of 1 means that the plane will pull about 1 g of acceleration to counter being 10m/s off from the target. During stable flight, this is plenty. During reentry, we'll encounter some much bigger errors, so I set limits on the PIDs. Currently, these are set to 20m/s^2 or a little more than 2gs.

Working with acceleration instead of pitch has some nice properties. For instance, working with pitch can mean very dramatic controls at hypersonic speeds. With accelerations, the pitch deviations will naturally be smaller when the horizontal speed is very high. Acceleration also remains legible ("A human can pull 9gs") at any speed or altitude.

The turning acceleration is already an acceleration, so there's no need to convert.

# Choosing Angle of Attack and Thrust
This section covers `flightControlUpdate`.

With a set of desired accelerations and an equation for lift and drag forces, we can choose a suitable aoa.

First, the turning, desired vertical speed change, and gravity are combined into one vector. We're assuming no sideslip, so all of that acceleration is coming from lift. Note that if the velocity vector has a vertical component, we'll need more lift to compensate for the fact that lift is off axis from gravity. If we're climbing at 45 degrees, we will need sqrt(2) * g lift in order to maintain the vertical speed.

Second, the desired lift quantity is combined with the lift equation to generate an aoa with the desired vertical acceleration. For level flight, this would be the aoa where lift exactly cancels gravity. Here, we add a term to the lift equation to factor in the vertical component of the current thrust. Since engines take time to change thrust, the current thrust is a good approximation for the thrust during the next tick. Using the small angle approximation for thrust * sin(aoa) yields:

`Lift = (Q * S * Cl + Thrust) * aoa.`

Third, the angle of attack is inputted into the drag equation to get the drag force to obtain a thrust force. Because the angle of attack reduces the component of thrust in the drag direction, we divide by `cos(aoa)`.

There are some safety limits to prevent chaos. The stable aoa output is limited to within 3 degrees of the current aoa. In addition, the turning acceleration is limited to some multiple, currently 1, of the vertical acceleration. This will limit the turn angle to an upper bound, currently 45 degrees, during times when vertical acceleration + gravity is close to 0 (desired lift close to 0).

Note, this method does not require tuning any PIDs. Any steady state error in lift/drag calculations can be corrected for by the integral term of the acceleration controllers, but this is generally small (< 0.5 m/s^2) in practice.