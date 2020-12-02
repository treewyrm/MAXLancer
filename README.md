# MAXLancer
MaxScript toolset for 3Ds MAX to import and export Freelancer 3db/cmp 3D models.

## Features
- Rigid model (.3db, .cmp) import and export, including LODs, hardpoints, HUD wireframes and compound joints.
- Deformable model (.dfm) import with animation scripts (.anm) (experimental feature).
- Collision detection surface (.sur) import and export. BHV validation.
- Material and texture (.mat, .txm) import and export.
- Automatic texture extraction, decompression and compression (using Nvidia Texture Tools).
- Convex mesh generation for surface hulls (using Nvidia PhysX/MassFX or built-in functions).

## Prerequisites
- Autodesk 3ds Max 2017 or above (tested with 3ds Max 2018)
- [Nvidia Texture Tools](https://github.com/castano/nvidia-texture-tools)
- Microsoft Freelancer

## Installation
By default installer will attempt to find most recent supported version of 3ds Max installed in the system.

After installation is complete follow these steps to finish the process:

### Create toolbar
- Open *Customize* → *Customize User Interface*.
- Switch to *Toolbars* tab.
- Press *New...* button to create new toolbar.
- In *Category* dropdown menu select MAXLancer.
- Drag and drop actions from the list below to newly made toolbar.

### Set external paths
- In MAXLancer sidebar press *Settings* button.
- Specify paths:
  - Freelancer (typically _C:\Program Files\Microsoft Games\Freelancer_).
  - Nvidia Texture Tools.
  - Textures (typically _C:\Users\[User]\Documents\3dsMax\sceneassets\images\MAXLancer_).
  - Shaders (typically _C:\Program Files\Autodesk\3ds Max 2018\maps\fx\MAXLancer_).
- Press OK button.

Path to Nvidia Texture Tools should point to binary folder (bin32 or bin64) containing executables.
If you have graphical issues with exported textures try using previous version of Texture Tools (2.1.1 for example).

### Disable gamma/LUT
- Open *Customize* → *Preferences* → *Gamma and LUT*.
- Uncheck *Enable Gamma\LUT Correction*.

Default settings in 3ds Max may overbright textures when previewed in viewport via DirectX shader. This will also affect exported textures.
