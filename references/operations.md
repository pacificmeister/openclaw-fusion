# Fusion 360 Operations Reference

## Table of Contents
- [Model Tree Navigation](#model-tree-navigation)
- [Sketches](#sketches)
- [Features](#features)
- [Boolean Operations](#boolean-operations)
- [Assembly](#assembly)
- [Patterns](#patterns)
- [Construction Geometry](#construction-geometry)
- [Measurement](#measurement)
- [Viewport & Screenshots](#viewport)

---

## Model Tree Navigation

```python
# List all components
for i in range(rootComponent.occurrences.count):
    occ = rootComponent.occurrences.item(i)
    print(f"Component: {occ.component.name}")

# List bodies in root
for i in range(rootComponent.bRepBodies.count):
    body = rootComponent.bRepBodies.item(i)
    print(f"Body: {body.name}, Volume: {body.volume:.2f} cm³")

# List sketches
for i in range(rootComponent.sketches.count):
    sk = rootComponent.sketches.item(i)
    print(f"Sketch: {sk.name}, Profiles: {sk.profiles.count}")

# List features (timeline)
for i in range(design.timeline.count):
    item = design.timeline.item(i)
    print(f"{i}: {item.entity.classType()} - healthy={item.isValid}")
```

## Sketches

### Create sketch on plane
```json
{"api_path": "design.rootComponent.sketches.add", "args": ["design.rootComponent.xYConstructionPlane"], "store_as": "sk"}
```
Planes: `xYConstructionPlane`, `xZConstructionPlane`, `yZConstructionPlane`

### Lines
```json
{"api_path": "$sk.sketchCurves.sketchLines.addByTwoPoints",
 "args": [{"type": "Point3D", "x": 0, "y": 0, "z": 0}, {"type": "Point3D", "x": 5, "y": 0, "z": 0}]}
```

### Rectangle
```json
{"api_path": "$sk.sketchCurves.sketchLines.addTwoPointRectangle",
 "args": [{"type": "Point3D", "x": 0, "y": 0, "z": 0}, {"type": "Point3D", "x": 10, "y": 5, "z": 0}]}
```

### Circle
```json
{"api_path": "$sk.sketchCurves.sketchCircles.addByCenterRadius",
 "args": [{"type": "Point3D", "x": 0, "y": 0, "z": 0}, 2.5]}
```

### Arc (three-point)
```json
{"api_path": "$sk.sketchCurves.sketchArcs.addByThreePoints",
 "args": [
   {"type": "Point3D", "x": 0, "y": 0, "z": 0},
   {"type": "Point3D", "x": 2.5, "y": 1, "z": 0},
   {"type": "Point3D", "x": 5, "y": 0, "z": 0}
 ]}
```

### Spline (fitted points)
```python
points = adsk.core.ObjectCollection.create()
for x, y in [(0,0), (2,3), (5,2), (8,4)]:
    points.add(adsk.core.Point3D.create(x, y, 0))
sketch.sketchCurves.sketchFittedSplines.add(points)
```

### Constraints (Python mode)
```python
lines = sketch.sketchCurves.sketchLines
constraints = sketch.geometricConstraints
dimensions = sketch.sketchDimensions

# Horizontal/vertical
constraints.addHorizontal(lines.item(0))
constraints.addVertical(lines.item(1))

# Perpendicular, parallel, tangent, coincident
constraints.addPerpendicular(lines.item(0), lines.item(1))
constraints.addParallel(lines.item(0), lines.item(2))
constraints.addCoincident(lines.item(0).startSketchPoint, lines.item(1).endSketchPoint)

# Dimensions
dimensions.addDistanceDimension(
    lines.item(0).startSketchPoint, lines.item(0).endSketchPoint,
    adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
    adsk.core.Point3D.create(2.5, -1, 0))
```

## Features

### Extrude
```json
{"api_path": "design.rootComponent.features.extrudeFeatures.createInput",
 "args": ["$sk.profiles.item(0)", 0], "store_as": "extInput"}
```
Then set distance and create:
```json
{"api_path": "$extInput.setDistanceExtent", "args": [false, {"type": "ValueInput", "expression": "10 mm"}]}
{"api_path": "design.rootComponent.features.extrudeFeatures.add", "args": ["$extInput"], "store_as": "ext1"}
```

Operation types (2nd arg of createInput): Join=0, Cut=1, Intersect=2, NewBody=3, NewComponent=4

### Extrude (Python — preferred for complex)
```python
prof = rootComponent.sketches.itemByName('Sketch1').profiles.item(0)
extrudes = rootComponent.features.extrudeFeatures
inp = extrudes.createInput(prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
inp.setDistanceExtent(False, adsk.core.ValueInput.createByReal(1.0))  # 1cm
ext = extrudes.add(inp)
print(f"Created: {ext.name}")
```

### Revolve
```python
prof = sketch.profiles.item(0)
axis = sketch.sketchCurves.sketchLines.item(0)  # axis line
revolves = rootComponent.features.revolveFeatures
inp = revolves.createInput(prof, axis, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
inp.setAngleExtent(False, adsk.core.ValueInput.createByString('360 deg'))
revolves.add(inp)
```

### Fillet
```python
fillets = rootComponent.features.filletFeatures
inp = fillets.createInput()
edges = adsk.core.ObjectCollection.create()
body = rootComponent.bRepBodies.item(0)
for edge in body.edges:
    edges.add(edge)
inp.addConstantRadiusEdgeSet(edges, adsk.core.ValueInput.createByReal(0.2), True)
fillets.add(inp)
```

### Chamfer
```python
chamfers = rootComponent.features.chamferFeatures
inp = chamfers.createInput2()
edges = adsk.core.ObjectCollection.create()
edges.add(body.edges.item(0))
inp.chamferEdgeSets.addEqualDistanceChamferEdgeSet(edges, adsk.core.ValueInput.createByReal(0.1), True)
chamfers.add(inp)
```

### Shell
```python
shells = rootComponent.features.shellFeatures
inp = shells.createInput([body.faces.item(0)])  # faces to remove
inp.insideThickness = adsk.core.ValueInput.createByReal(0.15)  # 1.5mm wall
shells.add(inp)
```

### Draft
```python
drafts = rootComponent.features.draftFeatures
inp = drafts.createInput(
    body.faces,  # faces to draft
    rootComponent.xZConstructionPlane,  # pull direction plane
    adsk.core.ValueInput.createByString('3 deg'))
drafts.add(inp)
```

### Loft
```python
lofts = rootComponent.features.loftFeatures
inp = lofts.createInput(adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
inp.loftSections.add(sketch1.profiles.item(0))
inp.loftSections.add(sketch2.profiles.item(0))
lofts.add(inp)
```

### Sweep
```python
sweeps = rootComponent.features.sweepFeatures
inp = sweeps.createInput(profile, path, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
sweeps.add(inp)
```

## Boolean Operations

```python
combines = rootComponent.features.combineFeatures
inp = combines.createInput(targetBody, adsk.core.ObjectCollection.create())
inp.toolBodies.add(toolBody)
inp.operation = adsk.fusion.FeatureOperations.CutFeatureOperation  # Join/Cut/Intersect
combines.add(inp)
```

## Assembly

### Rigid Joint
```python
joints = rootComponent.joints
geo0 = adsk.fusion.JointGeometry.createByPoint(occ1.component.originConstructionPoint)
geo1 = adsk.fusion.JointGeometry.createByPoint(occ2.component.originConstructionPoint)
inp = joints.createInput(geo0, geo1)
inp.setAsRigidJointMotion()
joints.add(inp)
```

### As-Built Joint
```python
asbj = rootComponent.asBuiltJoints
inp = asbj.createInput(occ1, occ2)
inp.setAsRigidJointMotion()
asbj.add(inp)
```

## Patterns

### Rectangular Pattern
```python
patterns = rootComponent.features.rectangularPatternFeatures
entities = adsk.core.ObjectCollection.create()
entities.add(feature)
inp = patterns.createInput(entities,
    rootComponent.xConstructionAxis,
    adsk.core.ValueInput.createByReal(3),   # count
    adsk.core.ValueInput.createByReal(2.0), # spacing cm
    adsk.fusion.PatternDistanceType.SpacingPatternDistanceType)
inp.setDirectionTwo(rootComponent.yConstructionAxis,
    adsk.core.ValueInput.createByReal(2),
    adsk.core.ValueInput.createByReal(2.0))
patterns.add(inp)
```

### Circular Pattern
```python
circPatterns = rootComponent.features.circularPatternFeatures
entities = adsk.core.ObjectCollection.create()
entities.add(feature)
inp = circPatterns.createInput(entities, rootComponent.zConstructionAxis)
inp.quantity = adsk.core.ValueInput.createByReal(6)
inp.totalAngle = adsk.core.ValueInput.createByString('360 deg')
circPatterns.add(inp)
```

### Mirror
```python
mirrors = rootComponent.features.mirrorFeatures
entities = adsk.core.ObjectCollection.create()
entities.add(feature)
inp = mirrors.createInput(entities, rootComponent.xYConstructionPlane)
mirrors.add(inp)
```

## Construction Geometry

```python
planes = rootComponent.constructionPlanes
inp = planes.createInput()

# Offset plane
inp.setByOffset(rootComponent.xYConstructionPlane, adsk.core.ValueInput.createByReal(5.0))
planes.add(inp)

# Plane at angle
inp2 = planes.createInput()
inp2.setByAngle(linearEdge, adsk.core.ValueInput.createByString('45 deg'), rootComponent.xYConstructionPlane)
planes.add(inp2)

# Construction axis
axes = rootComponent.constructionAxes
axInp = axes.createInput()
axInp.setByTwoPoints(point1, point2)
axes.add(axInp)

# Construction point
points = rootComponent.constructionPoints
ptInp = points.createInput()
ptInp.setByPoint(adsk.core.Point3D.create(5, 5, 5))
points.add(ptInp)
```

## Measurement

```python
# Distance between two points/entities
measMgr = app.measureManager
result = measMgr.measureMinimumDistance(body1, body2)
print(f"Distance: {result.value:.4f} cm")

# Bounding box
bb = body.boundingBox
size_x = bb.maxPoint.x - bb.minPoint.x
size_y = bb.maxPoint.y - bb.minPoint.y
size_z = bb.maxPoint.z - bb.minPoint.z
print(f"Size: {size_x:.2f} x {size_y:.2f} x {size_z:.2f} cm")

# Body properties
print(f"Volume: {body.volume:.4f} cm³")
print(f"Area: {body.area:.4f} cm²")

# Face area
for face in body.faces:
    print(f"Face area: {face.area:.4f} cm²")
```

## Viewport & Visual Verification

### Save Viewport Image
```python
app.activeViewport.saveAsImageFile('/tmp/fusion_viewport.png', 1920, 1080)
```

### Fit to View
```python
app.activeViewport.fit()
```

### Camera Control — Zoom to Feature
```python
cam = app.activeViewport.camera
cam.eye = adsk.core.Point3D.create(ex, ey, ez)      # camera position
cam.target = adsk.core.Point3D.create(tx, ty, tz)    # look-at point
cam.upVector = adsk.core.Vector3D.create(0, 0, 1)
cam.viewExtents = 5.0  # field of view in cm (~3× feature size)
cam.isSmoothTransition = False
app.activeViewport.camera = cam
app.activeViewport.refresh()
```

### Section Analysis (for verifying internal cuts)
```python
# Create temporary section plane + analysis
planes = rootComponent.constructionPlanes
inp = planes.createInput()
inp.setByOffset(
    rootComponent.xYConstructionPlane,
    adsk.core.ValueInput.createByReal(offset_cm)
)
section_plane = planes.add(inp)
section = rootComponent.analyses.createSectionAnalysis(section_plane)

# ... take screenshot and verify ...

# Clean up
section.deleteMe()
section_plane.deleteMe()
```

### Standard Views
```python
def set_view(viewport, eye, target, up=(0,0,1), extent=30):
    cam = viewport.camera
    cam.eye = adsk.core.Point3D.create(*eye)
    cam.target = adsk.core.Point3D.create(*target)
    cam.upVector = adsk.core.Vector3D.create(*up)
    cam.viewExtents = extent
    cam.isSmoothTransition = False
    viewport.camera = cam
    viewport.refresh()

# Front view (looking along -Y)
set_view(vp, (0, 50, 0), (0, 0, 0), (0, 0, 1), 30)

# Top view (looking along -Z)
set_view(vp, (0, 0, 50), (0, 0, 0), (0, 1, 0), 30)

# Isometric
set_view(vp, (20, 20, 20), (0, 0, 0), (0, 0, 1), 30)
```

### Verification After Boolean/Cut Operations
Always verify cuts visually — API "success" doesn't guarantee visible results.

1. Set camera to zoom into the cut area (`viewExtents` ≈ 3× cut radius)
2. Take screenshot → analyze with vision model
3. If cut is internal, also create a section analysis through the cut center
4. Compare pre/post body volume as secondary check
