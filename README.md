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

The critical workflow is **Execute → Screenshot → Evaluate → Iterate**. The agent always visually verifies results.

## License

MIT
