# Hardpoint Helper

**Command Panel ⟶ Create ⟶ Helpers ⟶ MAXLancer ⟶ Hardpoint**

Equipment, effects and other objects are attached to models via hardpoints. Freelancer has three types of hardpoints: fixed, revolute and prismatic.

Fixed hardpoints are simple points locked in place relative to their parent part.

Prismatic hardpoints were never used in game.

- Hardpoint names must be unique for model, within ASCII character range.
- Select type of joint from *Constraint Type* menu.
- *Axis vector* is used by Revolute and Prismatic hardpoints. It is expected to be normalized.
- Limits determine minimum and maximum value.

Revolute hardpoints allow for attached object to rotate across specified axis vector within minimum and maximum angles. Setting up rotation arc minimum and maximum to -360 and 360 angles will allow object to spin freely. Revolute hardpoints are typically used for guns and turrets.

*Base* and *Arrow* sizes determine helper display size in 3ds Max.

For attachment hardpoints a predefined collision hull can be specified in *Shape Type* and its size adjusted in *Hull size*.