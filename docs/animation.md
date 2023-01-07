# Compound Animation

Freelancer has a simple animation system in which a child part must specify a type of joint to its parent part and animation track(s) manipulate joint properties.

- *Fixed* is the simplest type of joint which does not allow any animation (although a part can still be made destroyable).
- *Revolute* joint acts as hinge allowing the object to swing along one axis vector within specified limits.
- *Prismatic* joint acts as rails allowing the object to slide along a vector within specified limits.
- *Cylindric* joint combines both revolute and prismatic, but at the moment it is not known what type of keyframe it uses.
- *Sphere* joint is like ball connector allowing free rotation but not any movement.
- *Loose* joint allows unconstrained rotation and movement.

In 3ds Max joints are represented by custom motion/transformation controllers. To specify joint type used by model part one of transform controllers must be assigned to its rigid part helper object.

- Fixed joint uses *Fixed Joint* controller.
- Revolute, Prismatic and Cylindric joints are used by *Axis Joint* controller.
- Sphere joint uses *Spheric Joint* controller, and loose joint uses *Loose Joint* controller.

For rigid models all animations must be embedded directly into .cmp file.

## Creating animation for parts

It's best to leave this part for the last after you've created model, LODs and put it together into hierarchy of parts.

> Save and backup your work before proceeding!

For each animated part repeat the following steps:

1. Select rigid part helper object in scene.
2. Open **Command Panel ⟶ Motion ⟶ Assign Controller**.
3. Select transform controller (by default it might be Position/Rotation/Scale Controller).
4. Click on *Assign Controller* button icon above.
5. Select *Axis Joint*, *Sphere Joint* or *Loose Joint* transform controller.

Next enable animation layers for the entire model:

1. Select Root (and only Root!) rigid part helper object of the model.
2. Open **Animation ⟶ Animation Layers**.
3. Click on *Enable Anim Layers* button.
4. Enable *Position*, *Rotation* and *Object parameters*.
5. Base Layer is created automatically. It cannot be deleted and is not exported.

To create new animation layer select Root rigid part helper and press *Add Anim Layer* button.

Axis Joint is animated by creating keyframes for tracks of slide or turn properties. Be aware that limits will prohibit values to exceed specified range regardless of keyframe values provided. If you see no visual changes from your animation track check limit values.

Direction of translation and/rotation is specified by *Axis vector*. It must be a unit vector, i.e. length of one. Use *Normalize* button to recalculate vector to unit length when modifying it manually. Translation and rotation are relative to parent part rather than the origin of the animated part.

For local axes of the part itself the vector can be calculated by selecting axis and pressing *Set Local Axis* button.

*Offset* vector is used by revolute joint but has no effect on prismatic joint.

Freelancer only does linear interpolation between keyframes, if you use other types of parameter sub-controllers, such as *Bezier Float*, the exporter will sample track for keyframes at a rate specified in **MAXLancer Panel ⟶ Settings ⟶ Animation ⟶ Sampling Rate (FPS)**.

For revolute joint where any turn between two keyframes should not exceed 180 degrees. A full turn should be broken by adding new keyframes within. While the result may seem right in 3ds Max it won't run as expected in game.