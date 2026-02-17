---
name: openclaw-fusion
description: Control Autodesk Fusion 360 via the AuraFriday MCP Server add-in. Use when the user wants to create, modify, measure, or inspect 3D CAD models, sketches, assemblies, or manufacturing setups in Fusion 360. Triggers on any Fusion/CAD/3D-modeling request.
---

# Fusion 360 Skill

Control Fusion 360 through the AuraFriday MCP-Link server. The server exposes a `fusion360` MCP tool with three execution modes: Generic API calls, Python execution, and documentation lookup.

## Connection

MCP-Link SSE endpoint: `https://127-0-0-1.local.aurafriday.com:31173/sse`

Use `mcporter` to call tools:

```bash
mcporter call fusion360.execute --args '{"api_path": "design.rootComponent.sketches.add", "args": ["design.rootComponent.xYConstructionPlane"]}'
```

Or configure in `config/mcporter.json`:
```json
{"mcpServers": {"fusion360": {"url": "https://127-0-0-1.local.aurafriday.com:31173/sse"}}}
```

Verify connection: `mcporter list fusion360 --schema`

## Three Execution Modes

### 1. Generic API — Simple operations

```json
{"api_path": "design.rootComponent.sketches.add", "args": ["design.rootComponent.xYConstructionPlane"], "store_as": "sketch1"}
```

- `api_path`: Dot-path into Fusion API. Prefix stored objects with `$` (e.g., `$sketch1.sketchCurves`)
- `args`: Array of arguments. Objects constructed from dicts: `{"type": "Point3D", "x": 5, "y": 10, "z": 0}`
- `store_as`: Save result for later use as `$name`

Supported object types in args:
- `{"type": "Point3D", "x": 0, "y": 0, "z": 0}`
- `{"type": "Vector3D", "x": 1, "y": 0, "z": 0}`
- `{"type": "ValueInput", "value": 2.5}` (cm) or `{"type": "ValueInput", "expression": "2.5 mm"}`
- `{"type": "ObjectCollection"}` (empty collection)
- Enum values as integers (e.g., `0` for `FeatureOperations.JoinFeatureOperation`)

### 2. Python Execution — Complex workflows

```json
{"operation": "execute_python", "code": "...python code..."}
```

Pre-injected variables: `app`, `ui`, `design`, `rootComponent`, `fusion_context` (stored objects dict), `mcp` (bridge to other tools).

Full access to `adsk.core`, `adsk.fusion`, `adsk.cam`. Use `print()` for return values.

### 3. Documentation Lookup

```json
{"operation": "get_api_documentation", "search_term": "ExtrudeFeature", "category": "class_name", "max_results": 5}
{"operation": "get_online_documentation", "class_name": "ExtrudeFeatures", "member_name": "createInput"}
{"operation": "get_best_practices"}
```

Always call `get_best_practices` on first use and `get_api_documentation` when unsure of API.

## Core Workflow: Execute → Verify → Iterate

**NEVER trust API return values alone.** Visual verification after every geometry operation is mandatory, not optional.

### The Verification Loop

Every geometry-changing operation follows this exact sequence:

1. **Zoom camera** to the target area BEFORE executing (~3× feature size)
2. **Execute** the Fusion operation
3. **Screenshot** the viewport immediately
4. **Quick vision check** — send screenshot to a **cheap/fast model** (Gemini Flash, ~$0.001/check)
5. **Pass/fail** — if the check fails, undo and fix immediately. Do NOT proceed.

Use this exact prompt format for quick checks:
```
I just [OPERATION] in Fusion 360.
Expected: [WHAT SHOULD BE VISIBLE]
Location: [WHERE ON THE MODEL]
Check: Is the change visible? Is it in the right place? Right direction?
```

Use `model="google/gemini-2.0-flash"` (or equivalent cheap model) for routine checks.
Reserve the main model for design decisions and complex analysis only.

**Cost:** ~$0.001 per check. 50 checks per session = $0.05. This is essentially free compared to the cost of blind debugging (which wastes 3-5× more API calls fixing compounded errors).

### Pre-Operation Checks

Before creating geometry, verify:
1. **Which body** am I modifying? (confirm it exists)
2. **Which sketch plane?** (XY/XZ/YZ — see direction table below)
3. **Which direction** will the extrude go?
4. **Will the tool body overlap the target?** (bounding box check for booleans)

### Sketch Plane Direction Table

This is the #1 source of errors. Memorize or reference before every sketch:

| Sketch Plane | Sketch X → | Sketch Y → | Extrude → |
|-------------|------------|------------|-----------|
| XY (offset in Z) | Model X | Model Y | ±Z |
| XZ (offset in Y) | Model X | Model Z | ±Y |
| YZ (offset in X) | Model Y | Model Z | ±X |

**⚠️ Offset planes can FLIP axes!** XZ plane offset in -Y flips sketch Y → -Z. Always verify with bounding box after first extrude.

### Boolean Pre-Check

Before any boolean cut, verify tool/target overlap:
```python
t_bb = tool_body.boundingBox
b_bb = target_body.boundingBox
overlap = (t_bb.maxPoint.x > b_bb.minPoint.x and t_bb.minPoint.x < b_bb.maxPoint.x and
           t_bb.maxPoint.y > b_bb.minPoint.y and t_bb.minPoint.y < b_bb.maxPoint.y and
           t_bb.maxPoint.z > b_bb.minPoint.z and t_bb.minPoint.z < b_bb.maxPoint.z)
if not overlap:
    print("WARNING: No overlap — boolean will fail!")
```

### Section Views for Internal Geometry

Cuts, pockets, bore holes — anything inside a body — need a section view to verify:

```python
planes = rootComponent.constructionPlanes
inp = planes.createInput()
inp.setByOffset(rootComponent.xYConstructionPlane, adsk.core.ValueInput.createByReal(offset_cm))
plane = planes.add(inp)
section = rootComponent.analyses.createSectionAnalysis(plane)
# ... screenshot + verify ...
section.deleteMe()
plane.deleteMe()
```

### Camera Control

```python
cam = app.activeViewport.camera
cam.eye = adsk.core.Point3D.create(ex, ey, ez)
cam.target = adsk.core.Point3D.create(tx, ty, tz)
cam.upVector = adsk.core.Vector3D.create(0, 0, 1)
cam.viewExtents = 5.0  # cm — ~3× feature size
cam.isSmoothTransition = False
app.activeViewport.camera = cam
app.activeViewport.refresh()
```

### Screenshot Helper

Combine camera + screenshot + viewport save in one Fusion call:
```python
# Zoom to area, screenshot, return path
cam = app.activeViewport.camera
cam.eye = adsk.core.Point3D.create(ex, ey, ez)
cam.target = adsk.core.Point3D.create(tx, ty, tz)
cam.upVector = adsk.core.Vector3D.create(0, 0, 1)
cam.viewExtents = extent
cam.isSmoothTransition = False
app.activeViewport.camera = cam
app.activeViewport.refresh()
path = '/tmp/fusion-verify.png'
app.activeViewport.saveAsImageFile(path, 1920, 1080)
print(f'SCREENSHOT:{path}')
```

Then: `cp /tmp/fusion-verify.png ~/clawd/fusion-verify.png` and use `image` tool with cheap model.

Load `references/verification-checklist.md` for the full checklist with failure examples from real builds.
Load `references/visual-feedback.md` for camera presets and section view patterns.

## Common Operations Reference

Load `references/operations.md` for detailed patterns covering:
- Sketches (lines, circles, arcs, rectangles, splines, constraints, dimensions)
- Features (extrude, revolve, fillet, chamfer, shell, draft, loft, sweep)
- Boolean operations (join, cut, intersect)
- Assembly (joints, as-built joints)
- Patterns (rectangular, circular, mirror)
- Construction geometry (planes, axes, points)
- Model tree navigation
- Measurement

## Key Gotchas

- **Units are cm** in the API. Always convert: 10mm = 1.0 in API.
- **store_as is essential** for multi-step operations. Store sketches, profiles, bodies, features.
- **Profile selection**: After creating a sketch, profiles are auto-generated. Access via `$sketch.profiles.item(0)`.
- **Extrude distance** uses ValueInput: `{"type": "ValueInput", "expression": "10 mm"}` or `{"value": 1.0}` (cm).
- **Boolean operations**: Set operation type as integer in ExtrudeInput — Join=0, Cut=1, Intersect=2, NewBody=3, NewComponent=4.
- **Thread safety**: All calls are queued to Fusion's main thread automatically. No concurrency issues.
- **Error handling**: Check response for `success` field. On failure, read the error message and adjust.
- **Python mode is preferred** for complex multi-step operations — fewer round trips, access to loops/conditionals.
