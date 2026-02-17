# Visual Feedback Loop Reference

## Why Visual Verification Matters

API return values lie. A boolean cut can "succeed" (no error) but produce invisible geometry changes because coordinates were wrong. A sketch can create profiles that look correct numerically but result in unexpected extrusions. **The only reliable check is visual.**

The hinge design lesson: trusting volume deltas ("2156 → 2136 cm³, must have worked!") without looking caused three failed iterations. A single screenshot after the first cut would have caught the Z-coordinate error immediately.

The iPhone build lesson: speaker holes took 5 attempts because each was debugged with bounding box numbers instead of screenshots. Camera lenses overlapped, buttons protruded instead of recessing, holes ended up outside the body. Every single failure would have been caught on attempt #1 by a $0.001 Gemini Flash check.

## Verification Tiers

### Tier 1: Always Verify (every geometry-changing operation)
- Boolean operations (cut, join, intersect, combine)
- Extrude, revolve, sweep, loft
- Fillet, chamfer, shell
- Pattern operations
- Any operation the user will see

**Method:** Screenshot after operation. If the operation involves internal geometry (cuts, pockets, channels), also take a section view.

### Tier 2: Spot-Check (verify periodically)
- Sketch creation (verify profile count and shape before extruding)
- Construction geometry (verify plane/axis position before using it)
- Component activation (verify correct component is active)

**Method:** Screenshot only if something seems off, or before committing to a dependent operation.

### Tier 3: Skip (no visual check needed)
- Reading model tree / listing components
- Querying measurements / bounding boxes
- Camera positioning (the next screenshot will show the result)
- Storing references with store_as
- Documentation lookups

## Screenshot Strategies

### 1. Standard Viewport Capture
```python
# Save viewport image directly from Fusion
app.activeViewport.saveAsImageFile('/tmp/fusion-check.png', 1920, 1080)
```
Or via shell: `screencapture -x /tmp/fusion-check.png`

Best for: Surface geometry, overall shape, positioning.

### 2. Zoomed View (Critical for Small Features)
```python
cam = app.activeViewport.camera
cam.eye = adsk.core.Point3D.create(ex, ey, ez)      # position
cam.target = adsk.core.Point3D.create(tx, ty, tz)    # look-at point
cam.upVector = adsk.core.Vector3D.create(0, 0, 1)    # up direction
cam.viewExtents = 5.0                                  # zoom level (cm)
cam.isSmoothTransition = False
app.activeViewport.camera = cam
app.activeViewport.refresh()
```

**Rule of thumb:** Set `viewExtents` to ~3× the size of the feature you're checking. For a 7mm radius hinge cut, viewExtents ≈ 5cm.

Best for: Small features, edge details, clearances.

### 3. Section View (Critical for Internal Geometry)
```python
# Create a temporary section analysis at the operation location
import adsk.core, adsk.fusion

# Create offset plane at the cut location
planes = rootComponent.constructionPlanes
planeInput = planes.createInput()
planeInput.setByOffset(
    rootComponent.xYConstructionPlane,  # or appropriate base plane
    adsk.core.ValueInput.createByReal(offset_cm)
)
section_plane = planes.add(planeInput)

# Create section analysis
analyses = rootComponent.analyses
section = analyses.createSectionAnalysis(section_plane)

# Screenshot here

# Clean up — delete section and construction plane
section.deleteMe()
section_plane.deleteMe()
```

Best for: Boolean cuts, internal pockets, channels, bore holes, any feature that removes material from inside a body.

### 4. Multi-Angle Verification (for final results / user presentation)
Take 3 shots:
1. **Isometric** — overall context
2. **Detail** — zoomed to the modified area
3. **Section** — if internal geometry exists

### 5. Before/After Comparison
Screenshot BEFORE the operation, then AFTER. When sending to vision model, include both with the prompt: "Compare these two views. What changed? Does the change match the intent: [describe expected change]?"

## Vision Analysis Prompts

### Quick Check (routine verification)
```
Look at this Fusion 360 viewport screenshot. I just performed [operation description].
Expected result: [what should be visible].
Does the geometry match? Any issues?
```

### Detailed Analysis (after failures or complex operations)
```
Compare these two Fusion 360 screenshots (before and after).
Operation performed: [description]
Expected change: [what should have changed]

1. What visible geometry changed between the images?
2. Does the change match the expected result?
3. Are there any unintended modifications?
4. Is the feature at the correct location and orientation?
```

### Section Analysis
```
This is a cross-section view through [location description].
I cut/added [feature description] at this location.
Expected cross-section: [describe expected profile shape]

1. Is the cut/feature visible in the section?
2. What are the approximate dimensions visible?
3. Does the profile shape match expectations?
```

## Camera Presets for Common Views

```python
def set_front_view(viewport, target_x=0, target_y=0, target_z=0, extent=30):
    """Look along -Y axis (front of wing)"""
    cam = viewport.camera
    cam.eye = adsk.core.Point3D.create(target_x, target_y + extent, target_z)
    cam.target = adsk.core.Point3D.create(target_x, target_y, target_z)
    cam.upVector = adsk.core.Vector3D.create(0, 0, 1)
    cam.viewExtents = extent
    cam.isSmoothTransition = False
    viewport.camera = cam
    viewport.refresh()

def set_top_view(viewport, target_x=0, target_y=0, target_z=0, extent=30):
    """Look along -Z axis (plan view)"""
    cam = viewport.camera
    cam.eye = adsk.core.Point3D.create(target_x, target_y, target_z + extent)
    cam.target = adsk.core.Point3D.create(target_x, target_y, target_z)
    cam.upVector = adsk.core.Vector3D.create(0, 1, 0)
    cam.viewExtents = extent
    cam.isSmoothTransition = False
    viewport.camera = cam
    viewport.refresh()

def set_iso_view(viewport, target_x=0, target_y=0, target_z=0, extent=30):
    """Standard isometric"""
    d = extent * 0.7
    cam = viewport.camera
    cam.eye = adsk.core.Point3D.create(target_x + d, target_y + d, target_z + d)
    cam.target = adsk.core.Point3D.create(target_x, target_y, target_z)
    cam.upVector = adsk.core.Vector3D.create(0, 0, 1)
    cam.viewExtents = extent
    cam.isSmoothTransition = False
    viewport.camera = cam
    viewport.refresh()

def zoom_to_point(viewport, x, y, z, radius_cm=5):
    """Zoom to a specific point with given radius of view"""
    cam = viewport.camera
    cam.eye = adsk.core.Point3D.create(x + radius_cm, y + radius_cm, z + radius_cm)
    cam.target = adsk.core.Point3D.create(x, y, z)
    cam.upVector = adsk.core.Vector3D.create(0, 0, 1)
    cam.viewExtents = radius_cm * 2
    cam.isSmoothTransition = False
    viewport.camera = cam
    viewport.refresh()
```

## Cost Optimization

### Two-Tier Vision Model System

| Check Type | Model | Cost/check | Use For |
|-----------|-------|-----------|---------|
| Quick check | Gemini Flash (`google/gemini-2.0-flash`) | ~$0.001 | Every geometry operation |
| Detailed review | Main model (Opus/Sonnet) | ~$0.03 | Before user presentation, complex analysis |

**Quick check prompt template:**
```
I just [OPERATION] in Fusion 360.
Expected: [WHAT SHOULD BE VISIBLE]
Location: [WHERE ON THE MODEL]
Check: Is the change visible? Is it in the right place? Right direction?
```

**Real-world results:** In the iPhone build, Gemini Flash correctly identified:
- "Buttons are protruding, not recessed" → caught direction error
- "Recesses are too square, need to be elongated" → caught proportion error
- "Speaker holes appear as rectangles, not circles" → caught sketch plane error

Each check: 2 seconds, $0.001. vs. debugging blind: 5+ attempts, 10× more tokens.

### Batch Operations Before Verifying
For a sequence of related operations (e.g., create sketch → add constraints → extrude), you can batch:
1. Create sketch
2. Add all geometry and constraints
3. Extrude
4. **Verify once** after the extrude (not after each sketch line)

But for independent operations on different bodies/locations, verify each one.

## The Verification Protocol

Every geometry-changing operation follows this pattern:

```
┌─────────────┐
│  Plan        │  What will this operation do? What should change?
└──────┬──────┘
       │
┌──────▼──────┐
│  Camera      │  Position viewport to show the target area
└──────┬──────┘
       │
┌──────▼──────┐
│  [Before]    │  Optional: capture pre-operation state
└──────┬──────┘
       │
┌──────▼──────┐
│  Execute     │  Run the Fusion operation
└──────┬──────┘
       │
┌──────▼──────┐
│  API Check   │  Did it return an error? Check volume/feature count.
└──────┬──────┘
       │
┌──────▼──────┐
│  Screenshot  │  Capture post-operation viewport
└──────┬──────┘
       │
┌──────▼──────┐
│  [Section]   │  If internal geometry: add section view screenshot
└──────┬──────┘
       │
┌──────▼──────┐
│  Analyze     │  Vision model: does visual match expectation?
└──────┬──────┘
       │
   ┌───┴───┐
   │ Pass?  │
   └───┬───┘
    Y  │  N
   ┌───▼───┐  ┌──────────┐
   │ Next   │  │ Diagnose │──▶ Undo + retry
   │ Step   │  │ & Fix    │
   └────────┘  └──────────┘
```
