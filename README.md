# openclaw-fusion

**The first CAD skill for OpenClaw** — give your AI agent hands and eyes inside Autodesk Fusion 360.

## What This Is

An OpenClaw skill that bridges AI agents to Fusion 360 through the [AuraFriday MCP Server](https://github.com/AuraFriday/Fusion-360-MCP-Server) add-in. Your agent can create 3D models, modify designs, measure geometry, and visually verify results — all through natural language.

The skill provides the **connection and API knowledge**. The engineering expertise (materials, tolerances, design patterns) comes from the AI model's training.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌────────────┐
│  You (chat)  │────▶│  OpenClaw    │────▶│  MCP-Link SSE   │────▶│  Fusion 360 │
│              │◀────│  Agent       │◀────│  :31173          │◀────│  Add-in     │
└─────────────┘     └──────────────┘     └─────────────────┘     └────────────┘
                     Uses mcporter        AuraFriday server       Executes API
                     to call tools        routes commands          calls on main
                                                                   thread
```

Everything runs **100% locally** on your machine. No cloud services.

## Prerequisites

1. **Autodesk Fusion 360** — installed and running
2. **AuraFriday MCP-Link Server** — [download installer](https://github.com/AuraFriday/mcp-link-server/releases/tag/latest)
3. **Fusion MCP Add-in** — [install from Autodesk App Store](https://apps.autodesk.com/FUSION/en/Detail/Index?id=7269770001970905100) or [clone from GitHub](https://github.com/AuraFriday/Fusion-360-MCP-Server)
4. **OpenClaw** — with `mcporter` available for MCP tool calls

## Installation

### Option A: ClewHub (when published)
```bash
clawhub install openclaw-fusion
```

### Option B: Manual
```bash
# Clone into your OpenClaw skills directory
git clone https://github.com/pacificmeister/openclaw-fusion.git
# Copy or symlink SKILL.md into your active skills
```

## What Your Agent Can Do

| Category | Capabilities |
|----------|-------------|
| **Sketches** | Lines, circles, arcs, splines, rectangles, constraints, dimensions |
| **Features** | Extrude, revolve, fillet, chamfer, shell, draft, loft, sweep |
| **Booleans** | Join, cut, intersect bodies |
| **Assembly** | Rigid/revolute/slider joints, as-built joints |
| **Patterns** | Rectangular, circular, mirror |
| **Construction** | Offset planes, axes, points |
| **Measurement** | Distances, volumes, areas, bounding boxes |
| **Navigation** | Browse model tree, list components/bodies/sketches |
| **Visual** | Screenshot viewport, fit view, camera control |

## Example Usage

> "Create a 50mm × 30mm × 20mm box with 2mm fillets on all edges and 4 mounting holes at the corners"

> "Measure the wall thickness of the selected body"

> "Add a circular pattern of 6 holes around the center axis"

> "Shell this body to 1.5mm wall thickness, removing the top face"

## How It Works

The skill teaches your OpenClaw agent three execution modes:

1. **Generic API** — JSON-based Fusion API calls for simple operations
2. **Python Execution** — Full Python with `adsk.*` access for complex workflows
3. **Documentation Lookup** — Query Fusion API docs when unsure

The critical workflow is **Execute → Verify → Iterate**. The agent visually verifies every geometry change.

## Visual Feedback Loop — What Makes This Different

Most Fusion 360 MCP integrations are "fire and forget" — they send commands and trust the API response. That doesn't work for real engineering. A boolean cut can "succeed" with wrong coordinates and produce invisible changes.

openclaw-fusion uses a **closed-loop visual verification system**:

1. **Camera positioning** — zoom to the area being modified
2. **Execute** the operation
3. **Screenshot** the viewport (+ section view for internal geometry)
4. **Vision analysis** — AI examines the screenshot to confirm the change matches intent
5. **Auto-retry** — if visual doesn't match, undo and adjust

This means the agent catches errors in real-time instead of discovering them 10 operations later. It can work on complex real-world models (not just "Hello World" boxes) because it actually sees what it's doing.

### Two-Tier Vision System

| Check Type | Model | Cost | When |
|-----------|-------|------|------|
| **Quick check** | Gemini Flash | ~$0.001 | After EVERY geometry operation |
| **Detailed review** | Main model (Opus/Sonnet) | ~$0.03 | Before presenting to user, complex analysis |

Quick checks use a simple prompt: *"I just [operation]. Expected [result]. Is the change visible? Right place? Right direction?"*

**Real-world impact:** In the iPhone 15 Pro test build, skipping quick checks led to 3-5 attempts per feature (speaker holes, USB-C port, camera lenses). With quick checks, each would have been caught on attempt #1. The cost of 50 quick checks ($0.05) is negligible compared to the cost of blind debugging (5× more API calls, 10× more tokens).

### Lessons from the iPhone Build

The first test model (iPhone 15 Pro, built entirely by AI) revealed critical failure patterns:

1. **Sketch plane orientation** — The #1 source of bugs. XZ plane offset in -Y flips the Z axis. The skill now includes a mandatory direction lookup table.
2. **Extrude direction** — Default direction often goes away from the target body. Always verify with bounding box overlap check before boolean operations.
3. **Through-holes must extend past the surface** — Holes that start inside the body are blind (invisible). Tool bodies must start outside and punch through.
4. **API "success" ≠ visible result** — A boolean cut can succeed with 0.1mm overlap that's invisible. Visual check catches this immediately.

## Project Structure

```
openclaw-fusion/
├── SKILL.md                        # Main skill definition (loaded by OpenClaw)
├── README.md                       # This file
├── LICENSE                         # MIT
├── references/
│   ├── operations.md               # Fusion API patterns & code snippets
│   ├── visual-feedback.md          # Camera presets & section view patterns
│   └── verification-checklist.md   # Mandatory verification steps & failure catalog
└── scripts/
    └── fusion-screenshot.sh        # Screenshot capture utility (macOS)
```

## License

MIT
