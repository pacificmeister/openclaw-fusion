# Verification Checklist — Mandatory Steps

## The Rule

**Every geometry-changing operation gets a visual check. No exceptions.**

This is not optional. This is not "when you have time." This is the core loop:

```
Execute → Screenshot → Quick Check → Proceed or Fix
```

## Quick Check Protocol (Gemini Flash — ~$0.001 per check)

After EVERY extrude, cut, boolean, fillet, or pattern:

1. **Zoom camera** to the modified area BEFORE the operation
2. **Execute** the operation
3. **Screenshot** immediately after
4. **Send to cheap vision model** with this exact prompt format:

```
I just [OPERATION] in Fusion 360.
Expected: [WHAT SHOULD BE VISIBLE]
Location: [WHERE ON THE MODEL]
Check: Is the change visible? Is it in the right place? Right direction?
```

Use `model="google/gemini-2.0-flash"` for these checks. Do NOT use the main model.

## What the Quick Check Catches

These are the actual failures from the iPhone build that visual checks would have caught immediately:

| Failure | Root Cause | Quick Check Would Have Shown |
|---------|-----------|------------------------------|
| Speaker holes as vertical stripes | Wrong sketch plane (XY instead of XZ) | "Holes appear as rectangles, not circles" |
| Speaker holes outside body | Z-axis flipped on offset XZ plane | "No visible change on the model" |
| Speaker holes blind (no surface opening) | Started inside body, didn't punch through | "No holes visible on the bottom face" |
| USB-C protruding below body | Tool body extended past body boundary | "Rectangle sticking out below the phone" |
| Camera lenses overlapping | 10mm spacing for 13mm diameter lenses | "Lenses are touching/overlapping" |
| Wrong extrude direction | Default direction away from body | "No target body found" (API error) |

**Every single one of these** would have been caught and fixed in one attempt instead of 3-5.

## Sketch Plane Direction Quick Reference

This is the #1 source of bugs. Before creating a sketch on a construction plane:

| Sketch Plane | Sketch X → Model | Sketch Y → Model | Extrude → Model |
|-------------|------------------|------------------|-----------------|
| XY (or offset in Z) | X | Y | ±Z |
| XZ (or offset in Y) | X | Z | ±Y |
| YZ (or offset in X) | Y | Z | ±X |

**⚠️ CRITICAL: Offset planes can FLIP axes!**
- XZ plane offset in **-Y** flips sketch Y → **-Z** in model space
- Always verify with a test point or bounding box check before committing

## Bounding Box Sanity Check

Before doing a boolean cut, verify the tool body overlaps the target:

```python
tool_bb = tool_body.boundingBox
body_bb = target_body.boundingBox

# Check overlap in all 3 axes
overlap_x = tool_bb.maxPoint.x > body_bb.minPoint.x and tool_bb.minPoint.x < body_bb.maxPoint.x
overlap_y = tool_bb.maxPoint.y > body_bb.minPoint.y and tool_bb.minPoint.y < body_bb.maxPoint.y
overlap_z = tool_bb.maxPoint.z > body_bb.minPoint.z and tool_bb.minPoint.z < body_bb.maxPoint.z

if not (overlap_x and overlap_y and overlap_z):
    print("WARNING: Tool body does not overlap target! Boolean will fail or be invisible.")
```

## Pre-Operation Checklist

Before any geometry operation, answer these:

1. **Which body am I modifying?** (name it, check it exists)
2. **What sketch plane am I on?** (XY/XZ/YZ, any offset?)
3. **Which direction will the extrude go?** (check the table above)
4. **Will the result be visible from outside?** (if not, plan a section view)
5. **Does my tool body overlap the target?** (bounding box check)

## Post-Operation Checklist

After every geometry operation:

1. ✅ Screenshot taken?
2. ✅ Sent to vision model?
3. ✅ Vision confirms change is visible?
4. ✅ Change is in the right location?
5. ✅ No unintended side effects?

If ANY check fails → **undo immediately** and diagnose before proceeding.
