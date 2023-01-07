# Dockable objects

Additional hardpoints are needed when making a model for dockable object to designate locations where ships should dock to.

Dockable object can have one or more docking bays and every docking bay needs at least **HpDockMount?** where ? is docking bay designation letter (A, B, etc). Hardpoint should be placed where ship disappears upon completing docking procedure or appears upon undocking. Hardpoint direction should be opposite to the entrance.

Next you can add approaching path with **HpDockPoint?NN** hardpoints where ? is the same docking bay letter and NN is path index starting at 01. **HpDockPoint?01** should be placed in front of the docking bay door and the highest index where ship will start approaching, typically it's just **HpDockPoint?02**. Orientation of points should be for approach, i.e. towards corresponding **HpDockMount?** hardpoint. Try to keep path start point outside the general bounding radius of the model to make docking autopilot work.

Optionally you can add hardpoints for camera placements that will be used during docking and undocking animated sequence. Docking camera hardpoint is **HpDockCam?** and undocking camera hardpoint is **HpLaunchCam?** where ? corresponds to docking bay letter. To make it easier to set camera hardpoint direction you can create a dummy object and have hardpoint look at it:

1. Select hardpoint helper object.
2. Go to **Command Panel ⟶ Motion tab ⟶ Assign Controller parameters**.
3. Select rotation controller and click on *Assign Controller* button.
4. Select *LookAt Constraint* controller.
5. Click on *Add LookAt Target* button and select target dummy.
6. Set *LookAt Axis* to Y. Leave Flip unchecked.
7. Set *Source Axis* and aligned to Upnode Axis to Z in Source/Upnode Alignment.
8. In the solar archetype for each docking bay add a line:

    docking_sphere = [type], [hardpoint], [distance], [animation script]

Type is "berth" for stations, "ring" for planetary docking rings, or "jump" for jumpgates ("moor_medium", "moor_large" are used by transport NPCs). Hardpoint is **HpDockMount?** (**HpDockMountA** for example). Distance is maximum distance from hardpoint to active docking sequence. Lastly animation script to open door can be added, for example "Sc_port dock open".