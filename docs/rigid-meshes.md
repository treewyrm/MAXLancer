# Rigid meshes

Freelancer stores rigid models in two types of files: .cmp and .3db. This includes ships, stations, asteroids, guns and turrets, system backgrounds and even user interface elements. Structurally they are similar except that .3db contains a single part model while .cmp contains multiple parts and is a container for multiple .3db fragments embedded within it.

Compound models (.cmp) are made of multiple individually named parts, which in turn refer to internally stored .3db to display them. Both formats typically have a mesh library (VMeshLibrary) which contains actual mesh data such as vertices, triangles and groups identifying what materials will be used to render them, i.e. the visual part that you see in game. For compound model there has to be at least one part called "Root". The rest are attached to this Root part or other parts forming up a simple tree hierarchy. Parts can be animated as well, for example open as doors for docking at station.

Each rigid part in a model may have different number of detail levels, for example Root part may have 3 levels while engine part may have 2.

It is not necssary to make a full set of LODs for every part but it is still highly recommended to do so for performance reasons, especially for large models with lots of materials and triangles. While modern graphics cards may be many times more powerful it is still relatively easy to saturate draw calls by having a lot of detailed models.

3ds Max provides multiple ways to progressively reduce geometry complexity and there are many third-party plugins providing similar functionality.

A part may have no meshes at all, useful to group multiple other parts for animation purposes.

Model parts provide only a reference to mesh and while mesh data is typically stored within model file this isn't the case for a number of files in user interface.

In 3ds Max LOD meshes are represented by *Editable mesh* object with *Level of Detail* attributes. Actual scene nodes can be of any geometry type as they are converted to editable mesh internally (and can be references/instances as well).

Mesh object name isn't used in exported model, it can be anything, but it is recommended to add suffix specifying what level it is and/or arrange LODs into 3ds Max layers.

## Level of Detail attributes

**MAXLancer ⟶ PanelRigid ⟶ Models ⟶ Levels of Detail ⟶ Apply**

Level of detail meshes is what rendered in game when you see the object. For exporter to recognize mesh as LOD it needs to be a geometry type node and have Level of Detail attributes assigned. The latter can be done in MAXLancer sidebar by selecting one or more geometry objects and clicking on *Apply* button at *Level of Detail* block in *Rigid Models* section. Selected meshes will then have a properties block *Level of Detail* where different options related to how the mesh will be interpreted and exported.

- Detail Level starts at zero for a fully detailed mesh. Ideally each subsequent level should have between half or two thirds of the previous level triangle count. In game the further you are from the object the more simplified mesh will be used to render it, this improves overall performance and reduces pixel flickering at distances.
- *View Range* determines the maximum view distance the level will be displayed at. However this value is often overriden by LODRanges property in INI archetypes.
- Enabling *Color and Transparency* will export vertex map channels 0 and -2 for color and transparency respetively. How they are used depends on material type. Most often it is used for nebula meshes in starspheres adding color tint to texture and soft fade transition at the edges.
- *UV Maps* sets number of UV pair coordinates, starting from vertex map channel 1. Most materials use only one UV map but certain special types, such as DetailMapMaterial uses two. Maximum number of UV maps allowed per Freelancer mesh format is 8 (vertex map channels 1 to 8 respectively).
- *Mesh Library Name* allows to manually specify mesh library name. By default LOD meshes are automatically sorted and grouped into buffer libraries and mesh buffer name is automatically generated. If your model exceeds buffer limit you can specify different name here to force mesh exported into a different library.

## Rigid Part helper

**Command Panel ⟶ Create ⟶ Helpers ⟶ MAXLancer ⟶ Rigid Part**

Ships, stations, scenery and generally most 3D assets in Freelancer as well as user interface elements are rigid models. Typically they are stored in .3db or .cmp files. .3db consist of a single model while .cmp contains one or more embedded .3db files with compound hierarchy.

In 3ds Max model parts are represented by Rigid part helper object. It acts as a group to contain different elements within: meshes for LODs, meshes for collision hulls, hardpoints, etc.

- Part names must be unique for model, within ASCII character range and maximum 64 characters.
- *Dummy Size* specifies helper model size. It has no effect in game.
- *Wireframe Snap* sets snap distance when wireframe shape knots are aligned to mesh vertices during export. Setting this value to 0 will require bit perfect match and is not recommended, you should leave some threshold for margin of error.
- If model has no subparts it will be exported as .3db file unless *Force Compound* is enabled at the root part - this will force model to be exported as compound (.cmp). Some models in Freelancer are required to be exported as compound even if they contain only single part, for example starspheres must be exported as compound models.
- Enabling *Force MultiLevel* forces parts with single LOD mesh to be exported as multi level. Useful for older tools.
- Enabling *Force LOD Center Zero* forces LOD mesh bounding sphere center to remain at zero relative to its part, otherwise center for LOD mesh bounding sphere is taken from mesh pivot, which may or may not be where rigid part helper is. Enable this for all parts in a starsphere model to avoid camera shifting away from the origin. LOD mesh boudning center also affects camera center for HUD wireframe display.

## Importing

To import rigid model click on *Import Rigid icon* in MAXLancer toolbar and select file to import.

- Enable *Hardpoints* to import model hardpoints as helper objects. Imported objects are automatically assigned to Hardpoints layer.
- Enable *Meshes* to import LOD meshes as Editable mesh with Level of Detail attributes. Imported objects are automatically assigned to Level layer(s), Level0 is visible and subsequent levels are hidden by default.
- Enable *Wireframes* to import HUD wireframes as Line objects. If meshes above are enabled the imported objects will be attached to associated LOD meshes. Imported objects are automatically assigned to Wireframes layer.
- Enable *Materials and Textures* to import materials and textures. First 24 materials are assigned to Compact Material Editor slots.
- Enable *Compound Animations* to import animation scripts into animation layers. By default all new animations layers will be muted and active layer will be reset to Base Layer.
- Enable *Collision Hulls* to import part hulls from .sur file matching model filename as Editable mesh. Imported objects are automatically assigned to Hulls layer. Individual convex hulls with matching ID will be merged into single mesh unless Hierarchy Volumes is enabled.
- Enable *Center of Mass* to import surface part center as Point helper object. They are used for aiming reticle. Imported objects are automatically assigned to Centers layer.

The following options are intended for debugging purposes:

- Enable *Bounds* to import LOD bounding volumes as helpers.
- Enabling *Keep Duplicates* retains duplicate hulls in fixed ancestor parts, otherwise they will be automatically deleted upon import to reduce clutter.
- Enabling *Group Hulls* imports group hulls of surface part as Editable mesh. Imported objects are automatically assigned to Wraps layer.
- Enabling *Boundary Extents* imports surface part boundary box as Dummy helper object. Imported objects are automatically assigned to Extents layer.
- Enabling *Hierarchy Volumes* imports surface part bounding volume hierarchy (BHV) nodes as Surface node object and colors wireframe based on intersection tests. Imported objects are assigned to Nodes layer.

If rigid model has no .sur file in the same folder matching filename or .sur contains no parts to match any parts in model file the Surface Components block will be disabled.

It is not necessary to arrange model object into layers for exporting but it is recommended to do so show/hide objects quicker to work on different types objects.

### Missing Resources

Any missing meshes, materials and textures will prompt to locate and search through additional files for them. Materials and textures are typically stored either in same folder or a parent folder.

- Press *Locate* button to manually specify file(s) containing missing resources. The dialog window will appear again if there are still missing resources in model.
- Press *Ignore* button to ignore missing resources and use placeholder material or texture. Mesh resources cannot be ignored however.
- Press *Auto-search* button to automatically find missing resources in Freelancer folder specified in MAXLancer settings.
- Press *Cancel* button to cancel importing procedure.

MAXLancer message log contains useful debug information during import. Specifically it logs which files contain materials found by auto-search function.

## Exporting

To export rigid model select root rigid part helper and click on *Export Rigid* icon in MAXLancer toolbar.

Children parts must have Fixed Joint, Fixed Axis Joint, Sphere Joint or Loose Joint transform controller.

Inspect tree list to the left to ensure all elements of model are detected correctly.

- Enable *Hardpoints* to export Hardpoint helper objects into model hardpoints. Hardpoints must be children of rigid part helper objects.
- Enable *Meshes* to export geometry objects with *Level of Detail* attributes as model LOD meshes. Embeds mesh library into model file.
- Enable *Wireframes* to export Line objects into model HUD wireframes. If spline object is attached to LOD mesh line knots (points) must be at vertices of mesh. Knot position doesn't have to be bit perfect match, but close enough (see *Wireframe Snap* in Rigid part helper above).
- Enable *Materials and Textures* to export and embed materials and textures into model file. When toggled off mesh groups will still refer to used material names.
- Enable *Compound Animations* to export and embeds animation library into model file. Available only to compound models with animation layers.
- Enable *Collision Surfaces* to exports any Editable mesh found in Rigid part helpers but not assigned to LODs into surface file.
- Enable *Force Convex* to reconvex collision hulls upon exporting.
- Enable *Timestamp Fragments* to adds timestamp marker to filenames of embedded .3db fragments in compound model.
- Enable *Add Exporter Version* to add exporter version entry in model file. Text message can be customized in MAXLancer settings.

### Destructible parts

Let's say you want to create damaged model for part *starboard_wing* which is attached to *Root*. Be aware a root part cannot have damaged model, only descendant parts can.

1. Create damaged part model as you would create single part model and name its rigid part helper as *dmg_starboard_wing*.
2. Once done align *dmg_starboard_wing* part helper to where you want it to appear on the main model.
3. For starboard_wing part parent (in this case Root) create hardpoint called DpStarboardWing. While the name doesn't have to match it is convinient to use the same.
4. In **MAXLancer Panel ⟶ Rigid Models ⟶ Destructible** parts click on *Assign* button.
5. First you will be prompted to pick what part the damage model is intended for: select *Li_star_wing_lod1* part helper.
6. Then you ll be prompted to pick damage part: select *dmg_starboard_wing* part helper.
7. Finally you'll be prompted to pick damage hardpoint: select *DpStarboardWing* hardpoint helper.
8. Lastly you will be prompted to confirm if you want to attach selected model as destructible part to specified ship part, press OK to link the parts. This links *dmg_starboard_wing* to *starboard_wing* as damaged model.
9. Now *dmg_starboard_wing* will be attached and locked to the ship model.

When you export main model now destructible parts will also be listed and exported alongside the main file.