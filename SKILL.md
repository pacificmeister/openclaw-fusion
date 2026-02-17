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

## Core Workflow: Execute → Screenshot → Evaluate → Iterate

1. **Execute** operation via mcporter call
2. **Screenshot** the viewport — use `get_viewport_image` or take screenshot via node/browser
3. **Evaluate** the result visually — check geometry, dimensions, alignment
4. **Iterate** — fix issues, refine, repeat

This feedback loop is essential. Never assume an operation succeeded without visual confirmation.

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
