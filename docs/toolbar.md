# Toolbar

Aside from main commands presented at MAXLancer toolbar the main panel contains various essential commands to the workflow.

## Alignment Tool

Alignment tool lets you quickly align any object to the surface of editable mesh.

1. Press *Select* button to pick object which you want to align. If you alreay have object selected it'll be picked automatically and this step is skipped.
2. Pick mesh object to which you want selected object to align to.
3. Move cursor to the point on mesh to align.
4. Click left mouse button to confirm position and alignment. Click right mouse button to cancel and return object to original position.
5. *Offset* provides height increase or decrease from the surfae.

Though primarily intended for snapping and aligning hardpoints and other helper objects to geometry it can be used for any object in scene.

## Rescale Model
Automatically scales selected model. Unlike regular scale tool this tool alters geometry of mesh objects rather than modifying transformation property of selected object(s), it also moves adjusts position of hardpoints and part helpers accordingly.

1. Set *Scale Factor* (1.0 = 100%).
2. Select only root rigid part helper(s).
3. Press *Apply* button to change scale of selected models. 

Freelancer does not support object scaling via transformation.

## Model Tools

- Select Map Channel and press Flip U or Flip V to flip horizontal or vertical coordinates for selected Editable mesh objects.

## Rigid Models

Contains useful tools for rigid models (.cmp and .3db) and setting up LOD meshes.

- Set *Size* and press *Apply* to change display size for all currently selected rigid part helpers.
- Press *Fixed*, *Revolute*, *Prismatic*, *Cylinder*, *Sphere* or *Loose* button to assign motion controller of that type to selected Rigid part helper objects.
- Set *Level*, *View Distance* and press *Apply* to add or modify *Level of Detail* attributes to selected geometry objects.
- Press *Clear* button to remove Level of Detail attributes from selected geometry objects.

- Press *Create Wireframes* to create Line object(s) from visible edges of selected Editable mesh objects. Resulting objects are automatically added to Wireframes layers and attached to their origin mesh object.

- Press *Reset Transforms* to apply *XForm Reset* modifier on all selected objects. Nested objects are removed from hierarchy into Scene Root. Often this is necessary for meshes imported from other modeling applications.
- Press *Reset Center Pivots* to reset pivots on all selected objects.

## Hardpoints

- Set *Base Size*, *Arrow Size* and press *Apply* to change display size for hardpoint helpers in selection.
- Set *Constraint Type*, minimum and maximum limits, and press *Apply* to change type and limit properties for hardpoint helpers in selection.
- Set *Shape Type*, *Size* and press *Apply* to change hull properties for hardpoint helpers in selection.

In *Mirror Hardpoints* press X, Y or Z button to to clone hardpoint helpers in selection across specified axis relative to the Root part of the model. Be sure to attach cloned hardpoint helpers to correct parts!

Enable *Flip* revolute min/max limits to negate and swap around min/max limits.

Press *Align to Hardpoint* button to select source hardpoint helper object of model you wish to align, then select target hardpoint helper object of a different model. Source and target hardpoint helpers must belong to different models.

Press *Convert to Hardpoints* button to replace all selected objects with hardpoint helpers. Used when importing model from another application where hardpoints are often substituted by a dummy mesh object.