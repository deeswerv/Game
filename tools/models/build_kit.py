# The city kit: real meshes for Downtown's street props, modelled in code with Blender.
#
#   python -m venv .venv && .venv/bin/pip install bpy        (Blender as a Python module)
#   .venv/bin/python tools/models/build_kit.py [outdir]       (default assets/models)
#
# Writes:
#   CityKit.glb / CityKit.fbx   every model, each an Empty holding one mesh per material role
#                               (Body, Glass, Chrome, Tyre...), so a whole car is a handful of
#                               MeshParts instead of forty bricks
#   previews/<Model>.png        a render of each, and previews/sheet.png of them all
#   src/ServerScriptService/DistrictService/MeshKitData.luau
#                               the manifest the game places them by: every piece's size and
#                               offset in studs, in Roblox's frame (+Y up, the model facing -Z)
#
# Blender here is Z-up with the model facing +Y; glTF/Roblox is Y-up facing -Z. One Blender
# unit is one stud. Every piece is centred on its own bounding box with no rotation, so its
# MeshPart's Size is its box and the manifest's offset puts it back where it was modelled.

import base64
import math
import os
import random
import struct
import sys

import bpy  # noqa: E402  (bpy first: bmesh and mathutils come with it)
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.join(ROOT, "assets", "models")
MANIFEST = os.path.join(ROOT, "src", "ReplicatedStorage", "MeshKitData.luau")
GEOMETRY = os.path.join(ROOT, "src", "ReplicatedStorage", "MeshKitGeometry.luau")

# Preview colours per role (the game colours each piece itself; these are only for renders).
PREVIEW = {
    "Body": (0.80, 0.18, 0.16), "Glass": (0.10, 0.16, 0.24), "Chrome": (0.78, 0.79, 0.82), "Tyre": (0.05, 0.05, 0.06),
    "Rim": (0.70, 0.71, 0.74), "LampFront": (1.0, 0.97, 0.85), "LampRear": (0.75, 0.08, 0.08), "Trim": (0.10, 0.10, 0.12),
    "Iron": (0.16, 0.22, 0.20), "LanternGlass": (1.0, 0.92, 0.70), "Trunk": (0.36, 0.24, 0.16),
    "Leaves1": (0.16, 0.42, 0.16), "Leaves2": (0.28, 0.58, 0.22), "Leaves3": (0.48, 0.74, 0.30),
    "Paint": (0.55, 0.30, 0.80), "Red": (0.78, 0.16, 0.12), "Gold": (0.90, 0.66, 0.16), "Wood": (0.62, 0.42, 0.24),
    "Stone": (0.72, 0.68, 0.62), "Water": (0.25, 0.55, 0.75), "Pole": (0.08, 0.08, 0.09), "Head": (0.92, 0.75, 0.15),
    "SignalRed": (0.5, 0.1, 0.1), "SignalAmber": (0.5, 0.36, 0.1), "SignalGreen": (0.3, 0.92, 0.45), "Blade": (0.13, 0.46, 0.3),
    "WalkLamp": (0.97, 0.97, 0.95), "Lid": (0.2, 0.32, 0.22), "Wheel": (0.1, 0.1, 0.1), "Band": (0.12, 0.12, 0.13),
    "Bloom": (0.95, 0.45, 0.65), "Stripe": (0.96, 0.95, 0.9),
    "Blossom1": (0.91, 0.52, 0.67), "Blossom2": (0.96, 0.69, 0.79), "Blossom3": (0.99, 0.83, 0.89),
    "Pine1": (0.18, 0.36, 0.25), "Pine2": (0.23, 0.42, 0.29), "Dark": (0.08, 0.08, 0.09),
    "WingL": (0.55, 0.57, 0.62), "WingR": (0.55, 0.57, 0.62), "Feet": (0.85, 0.45, 0.45),
    "Counter": (0.96, 0.95, 0.92), "AwningA": (0.85, 0.24, 0.2), "AwningB": (0.96, 0.95, 0.92), "Top": (0.96, 0.95, 0.92),
    "CanopyA": (0.9, 0.35, 0.38), "CanopyB": (0.96, 0.95, 0.92), "Chair": (0.9, 0.35, 0.38), "Black": (0.12, 0.13, 0.16),
    "Fabric": (0.2, 0.6, 0.55),
}

random.seed(7)


# ------------------------------------------------------------------------------- helpers --

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me))


def add_box(bm, centre, size, bevel=0.0, segments=2):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
    if bevel > 0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bevel, min(size) * 0.45), segments=segments,
                        affect="EDGES", profile=0.5)
    bmesh.ops.translate(tmp, vec=Vector(centre), verts=tmp.verts)
    merge(bm, tmp)


def add_cylinder(bm, centre, radius, depth, axis="Z", segments=24, radius2=None, bevel=0.0, cap=True):
    tmp = bmesh.new()
    bmesh.ops.create_cone(tmp, cap_ends=cap, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=depth)
    if bevel > 0:
        rim = [e for e in tmp.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.z) > 0.9
               or (len(e.link_faces) == 2 and abs(e.link_faces[1].normal.z) > 0.9)]
        bmesh.ops.bevel(tmp, geom=rim, offset=bevel, segments=2, affect="EDGES", profile=0.5)
    if axis == "X":
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(tmp, vec=Vector(centre), verts=tmp.verts)
    merge(bm, tmp)


def add_sphere(bm, centre, radius, subdiv=2, squash=1.0, noise=0.0):
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=radius)
    for v in tmp.verts:
        n = v.co.normalized()
        bump = 1 + noise * (math.sin(n.x * 7.1 + centre[0]) * math.sin(n.y * 6.3 + centre[1]) * math.sin(n.z * 5.7 + centre[2]))
        v.co = v.co * bump
        v.co.z *= squash
    bmesh.ops.translate(tmp, vec=Vector(centre), verts=tmp.verts)
    merge(bm, tmp)


def add_lathe(bm, profile, centre=(0, 0, 0), segments=24):
    """Spin a (radius, z) profile round Z."""
    tmp = bmesh.new()
    verts = [tmp.verts.new((r, 0, z)) for r, z in profile]
    edges = [tmp.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(tmp, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.pi * 2, steps=segments,
                   use_merge=True)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts, dist=1e-4)
    bmesh.ops.translate(tmp, vec=Vector(centre), verts=tmp.verts)
    merge(bm, tmp)


def add_profile(bm, points_yz, x0, x1, bevel=0.0, segments=2):
    """A side profile (y, z) extruded across x from x0 to x1: car bodies, bench ends."""
    tmp = bmesh.new()
    verts = [tmp.verts.new((x0, y, z)) for y, z in points_yz]
    face = tmp.faces.new(verts)
    res = bmesh.ops.extrude_face_region(tmp, geom=[face])
    moved = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(tmp, vec=(x1 - x0, 0, 0), verts=moved)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if bevel > 0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=segments, affect="EDGES", profile=0.5,
                        clamp_overlap=True)
    merge(bm, tmp)


def add_tube(bm, points, radius, segments=10):
    """A tube along a polyline of (x, y, z) points (lamp crooks, bench curls)."""
    for a, b in zip(points[:-1], points[1:]):
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length + radius)
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=rot)
        bmesh.ops.translate(tmp, vec=(a + b) / 2, verts=tmp.verts)
        merge(bm, tmp)


def merge(dst, src):
    me = bpy.data.meshes.new("_tmp")
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def cut(obj, cutter_bm):
    """Boolean difference of obj with a mesh (wheel arches)."""
    cutter = mesh_object("_cutter", cutter_bm)
    mod = obj.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)


def finish(obj, smooth_angle=0.6):
    """Smooth shading with hard edges past `smooth_angle`, transforms applied."""
    for p in obj.data.polygons:
        p.use_smooth = True
    try:
        obj.data.set_sharp_from_angle(angle=smooth_angle)
    except AttributeError:
        pass
    return obj


# Every model: an Empty named for it with one mesh child per role.
MODELS = {}


def model(name, pieces):
    """pieces: { role: bmesh }"""
    empty = link(bpy.data.objects.new(name, None))
    objs = []
    for role, bm in pieces.items():
        if isinstance(bm, bpy.types.Object):
            obj = bm
            obj.name = f"{name}_{role}"
            obj.data.name = obj.name
        else:
            obj = mesh_object(f"{name}_{role}", bm)
        # Every face out: Roblox draws one side of a triangle only.
        fix = bmesh.new()
        fix.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(fix, faces=fix.faces)
        fix.to_mesh(obj.data)
        fix.free()
        finish(obj)
        mat = bpy.data.materials.get(role) or bpy.data.materials.new(role)
        mat.diffuse_color = (*PREVIEW.get(role, (0.6, 0.6, 0.6)), 1)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*PREVIEW.get(role, (0.6, 0.6, 0.6)), 1)
            bsdf.inputs["Roughness"].default_value = 0.25 if role in ("Glass", "Chrome", "Rim", "LanternGlass") else 0.6
            if role in ("Chrome", "Rim"):
                bsdf.inputs["Metallic"].default_value = 0.9
        obj.data.materials.append(mat)
        obj.parent = empty
        objs.append(obj)
    MODELS[name] = (empty, objs)
    return empty


# -------------------------------------------------------------------------------- cars --
#
# One generator, three bodies. Studs, matching the part-built cars: W wide (X), L long (Y),
# the nose at +Y (Roblox's -Z), wheels of radius r at the axles.

def car(name, L, W, r, axles, belt, roof, cabin, nose, tail, ride=0.45, rails=False, spare=False, radii=None,
        arch=0.14, muscle=False):
    hl = L / 2
    radii = radii or [r for _ in axles]       # each axle's tyre radius
    # The lower body: a side profile, bevelled round every edge, with the arches cut out.
    lower = bmesh.new()
    # The bonnet is kept above the tyres (the arches are cut no higher than a tyre's top), so
    # the arches never break through it.
    prof = [(-hl, ride + 0.25), (-hl + 0.15, ride), (hl - 0.15, ride), (hl, ride + 0.25),
            (hl, belt - 0.35), (hl - nose * 0.25, belt - 0.1), (hl - nose, belt), (-hl + tail, belt),
            (-hl + 0.1, belt - 0.15), (-hl, belt - 0.35)]
    add_profile(lower, prof, -W / 2, W / 2, bevel=0.22, segments=3)
    body = mesh_object(f"{name}_BodyTmp", lower)
    arches = bmesh.new()
    for y, rr in zip(axles, radii):
        add_cylinder(arches, (0, y, rr), rr + arch, W + 1, axis="X", segments=32)
    cut(body, arches)
    # The roof: a slab over the glass house.
    c0, c1, c2, c3 = cabin       # rear-of-roof y, front-of-roof y, windscreen base y (ahead of c1),
                                 # rear glass base y (behind c0)
    roof_bm = bmesh.new()
    add_box(roof_bm, (0, (c0 + c1) / 2, roof - 0.12), (W - 0.55, c1 - c0, 0.24), bevel=0.1)
    if rails:
        for x in (-1, 1):
            add_box(roof_bm, (x * (W / 2 - 0.55), (c0 + c1) / 2, roof + 0.1), (0.14, (c1 - c0) * 0.85, 0.14), bevel=0.04)
    # Fold the roof into the body piece.
    bm2 = bmesh.new()
    bm2.from_mesh(body.data)
    merge(bm2, roof_bm)
    bm2.to_mesh(body.data)
    bm2.free()
    # The glass house: a trapezoid profile (raked screens front and back), a touch narrower.
    glass = bmesh.new()
    gprof = [(c3, belt), (c2, belt), (c1, roof - 0.22), (c0, roof - 0.22)]
    add_profile(glass, gprof, -(W / 2 - 0.35), W / 2 - 0.35, bevel=0.08)
    # The window frames, set just proud of the glass: A pillars up the windscreen, C pillars down
    # the rear glass, a B pillar between the doors, and a drip rail along the roof edge.
    pillars = bmesh.new()
    mid = (c0 + c1) / 2
    top = roof - 0.22
    for x in (-1, 1):
        px = x * (W / 2 - 0.3)
        add_tube(pillars, [(px, c2, belt), (px, c1, top)], 0.1, segments=8)
        add_tube(pillars, [(px, c3, belt), (px, c0, top)], 0.1, segments=8)
        add_box(pillars, (px, mid, (belt + top) / 2), (0.12, 0.24, top - belt))
        add_box(pillars, (px, mid, top - 0.02), (0.12, c1 - c0, 0.1))
        # Door shut lines down the side, front door and rear.
        for y in (c2 - 0.15, mid, c0 - 0.35):
            add_box(pillars, (x * (W / 2 + 0.005), y, (ride + belt) / 2 + 0.1), (0.03, 0.05, belt - ride - 0.55))
    # Chrome: bumpers front and back, a grille, belt lines, handles.
    chrome = bmesh.new()
    for s in (-1, 1):
        add_box(chrome, (0, s * (hl + 0.05), ride + 0.45), (W - 0.2, 0.35, 0.38), bevel=0.12)
    add_box(chrome, (0, hl + 0.04, belt - 0.85), (W * 0.42, 0.12, 0.4), bevel=0.05)
    for x in (-1, 1):
        add_box(chrome, (x * (W / 2 + 0.01), (c3 + c2) / 2, belt + 0.02), (0.06, abs(c2 - c3), 0.08))
        for y in (mid - 0.8, mid + 0.8):
            add_box(chrome, (x * (W / 2 + 0.02), y, belt - 0.35), (0.08, 0.45, 0.12), bevel=0.03)
        add_box(chrome, (x * (W / 2 + 0.08), c2 - 0.25, belt + 0.18), (0.36, 0.28, 0.24), bevel=0.08)   # mirrors
    # Lamps, set into the corners.
    front, rear = bmesh.new(), bmesh.new()
    for x in (-1, 1):
        add_box(front, (x * (W / 2 - 0.65), hl - 0.02, belt - 0.6), (0.95, 0.2, 0.34), bevel=0.08)
        add_box(rear, (x * (W / 2 - 0.55), -hl + 0.02, belt - 0.58), (0.8, 0.2, 0.3), bevel=0.08)
    # Wheels: tyre with a rounded shoulder; five-spoke rim with a hub.
    tyre, rim = bmesh.new(), bmesh.new()
    for x in (-1, 1):
        for y, r in zip(axles, radii):
            cx = x * (W / 2 - 0.32)
            add_lathe_x(tyre, [(r * 0.62, -0.36), (r * 0.92, -0.38), (r, -0.25), (r, 0.25), (r * 0.92, 0.38), (r * 0.62, 0.36)],
                        (cx, y, r), x)
            add_cylinder(rim, (cx + x * 0.3, y, r), r * 0.6, 0.12, axis="X", segments=24)
            add_cylinder(rim, (cx + x * 0.36, y, r), r * 0.18, 0.14, axis="X", segments=12)
            for k in range(5):
                a = k * math.pi * 2 / 5
                tmp = bmesh.new()
                bmesh.ops.create_cube(tmp, size=1.0)
                bmesh.ops.scale(tmp, vec=(0.1, 0.16, r * 1.08), verts=tmp.verts)
                bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(a, 3, "X"))
                bmesh.ops.translate(tmp, vec=(cx + x * 0.36, y, r), verts=tmp.verts)
                merge(rim, tmp)
    if muscle:
        # Racing stripes over the roof and the boot, a scoop on the bonnet, a wing on posts,
        # twin pipes.
        stripes = bmesh.new()
        for x in (-0.55, 0.55):
            add_box(stripes, (x, (c0 + c1) / 2, roof + 0.005), (0.5, c1 - c0 - 0.1, 0.02))
            add_box(stripes, (x, (-hl + 0.3 + c3) / 2, belt + 0.005), (0.5, c3 + hl - 0.4, 0.02))
        add_box(pillars, (0, hl - nose * 0.55, belt + 0.12), (1.8, 2.2, 0.36), bevel=0.12)
        add_box(pillars, (0, -hl + 0.55, belt + 0.62), (W - 0.3, 0.9, 0.18), bevel=0.06)
        for x in (-1.9, 1.9):
            add_box(pillars, (x, -hl + 0.6, belt + 0.28), (0.22, 0.4, 0.55))
            add_cylinder(chrome, (x * 0.35, -hl - 0.15, ride + 0.35), 0.18, 0.7, axis="Y", segments=12)
    pieces = {"Body": body, "Glass": glass, "Chrome": chrome, "LampFront": front, "LampRear": rear, "Tyre": tyre, "Rim": rim,
              "Trim": pillars}
    if muscle:
        pieces["Stripe"] = stripes
    if spare:
        sp = bmesh.new()
        add_cylinder(sp, (0, -hl - 0.35, belt - 0.2), r * 0.95, 0.6, axis="Y", segments=24, bevel=0.1)
        pieces["Spare"] = sp
    return model(name, pieces)


def add_lathe_x(bm, profile, centre, side):
    """A lathe round X (wheels): profile of (radius, x offset)."""
    tmp = bmesh.new()
    add_lathe(tmp, [(rr, z) for rr, z in profile], (0, 0, 0), segments=28)
    bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    bmesh.ops.translate(tmp, vec=Vector(centre), verts=tmp.verts)
    merge(bm, tmp)


# --------------------------------------------------------------------------- the others --

def street_lamp():
    """The avenue lamp: plinth, fluted pole, a crook over toward -X, a lantern globe.
    Matches lamp(): globe centred at (-3.8, 14.1), crook top at 17.9 (Roblox y)."""
    iron = bmesh.new()
    add_lathe(iron, [(0.0, 0.0), (0.85, 0.0), (0.85, 0.35), (0.7, 0.5), (0.7, 1.6), (0.55, 1.8), (0.4, 2.1), (0.3, 2.4),
                     (0.27, 2.4), (0.0, 2.4)], segments=8)
    add_cylinder(iron, (0, 0, 9.0), 0.25, 13.6, segments=12, radius2=0.2)
    for z in (5.8, 6.2, 15.6):
        add_cylinder(iron, (0, 0, z), 0.36, 0.25, segments=12, bevel=0.06)
    # The crook: a half circle from the pole top over to -X.
    pts = []
    rr, cx, cy = 1.9, -1.9, 16.0
    for k in range(0, 13):
        a = k / 12 * math.pi
        pts.append((cx + math.cos(a) * rr, 0, cy + math.sin(a) * rr))
    add_tube(iron, pts, 0.2, segments=8)
    add_sphere(iron, (cx, 0, cy + rr + 0.05), 0.3, subdiv=1)
    lx = cx - rr
    add_cylinder(iron, (lx, 0, cy - 0.4), 0.08, 0.8, segments=8)
    add_lathe(iron, [(0.0, 0.0), (0.95, 0.0), (0.7, 0.35), (0.25, 0.6), (0.1, 0.9), (0.0, 0.95)], (lx, 0, cy - 1.1), segments=16)
    add_lathe(iron, [(0.0, 0.0), (0.4, 0.0), (0.35, 0.3), (0.0, 0.3)], (lx, 0, cy - 2.95), segments=12)
    glass = bmesh.new()
    add_sphere(glass, (lx, 0, cy - 1.9), 0.85, subdiv=3)
    return model("StreetLamp", {"Iron": iron, "LanternGlass": glass})


def tree(name, height=1.0):
    """A full, leafy tree: a trunk that forks into three limbs, and a canopy of lumpy clumps in
    three greens, darkest underneath, lightest on top where the sun catches it."""
    trunk = bmesh.new()
    add_cylinder(trunk, (0, 0, 3.0 * height), 0.55, 6.0 * height, segments=10, radius2=0.4)
    add_cylinder(trunk, (0, 0, 0.45), 0.85, 0.9, segments=10, radius2=0.55)
    for a, lean in ((0.4, 0.6), (2.5, 0.55), (4.3, 0.5)):
        mid = (math.cos(a) * 1.0, math.sin(a) * 1.0, (6.9 + lean * 0.5) * height)
        top = (math.cos(a) * 2.4, math.sin(a) * 2.4, (8.4 + lean) * height)
        add_tube(trunk, [(0, 0, 5.6 * height), mid, top], 0.28, segments=8)
    shades = {"Leaves1": bmesh.new(), "Leaves2": bmesh.new(), "Leaves3": bmesh.new()}
    rng = random.Random(len(name))
    # Three tiers of clumps: a wide skirt, a middle, a crown.
    tiers = ((9, 3.3, 8.6, (2.0, 2.6), "Leaves1"), (8, 2.4, 10.6, (2.1, 2.7), "Leaves2"), (5, 1.3, 12.4, (1.8, 2.4), "Leaves3"))
    for count, ring, z0, (s0, s1), role in tiers:
        for k in range(count):
            a = k / count * math.pi * 2 + rng.uniform(-0.25, 0.25) + (0.4 if role == "Leaves2" else 0)
            rr = ring * rng.uniform(0.85, 1.1)
            z = z0 * height + rng.uniform(-0.45, 0.45)
            add_sphere(shades[role], (math.cos(a) * rr, math.sin(a) * rr, z), rng.uniform(s0, s1), subdiv=2, squash=0.82,
                       noise=0.16)
    add_sphere(shades["Leaves2"], (0, 0, 10.2 * height), 2.9, subdiv=2, squash=0.85, noise=0.1)
    add_sphere(shades["Leaves3"], (0.2, -0.1, 13.6 * height), 1.8, subdiv=2, squash=0.8, noise=0.14)
    return model(name, {"Trunk": trunk, **shades})


def bench():
    """A park bench: curved cast-iron ends with scrolled arms, five slats. Faces +Y (the sitter
    looks toward Roblox -Z), like bench()."""
    iron = bmesh.new()
    end = [(-0.8, 0.0), (-0.55, 0.0), (-0.45, 1.5), (0.6, 1.55), (0.75, 0.0), (0.95, 0.0), (0.8, 1.7),
           (0.95, 3.4), (0.75, 3.45), (0.6, 1.85), (-0.6, 1.8), (-0.75, 2.6), (-0.95, 2.6), (-0.7, 1.5)]
    for x in (-2.6, 2.6):
        add_profile(iron, [(-y, z) for y, z in end], x - 0.12, x + 0.12, bevel=0.05)
        add_cylinder(iron, (x, 0.85, 2.6), 0.22, 0.3, axis="X", segments=12)
    wood = bmesh.new()
    for i, y in enumerate((-0.6, 0.0, 0.6)):
        add_box(wood, (0, -y, 1.95), (6.1, 0.46, 0.14), bevel=0.05)
    for i, z in enumerate((2.6, 3.2)):
        tmp = bmesh.new()
        add_box(tmp, (0, 0, 0), (6.1, 0.18, 0.46), bevel=0.05)
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.radians(12), 3, "X"))
        bmesh.ops.translate(tmp, vec=(0, -(0.82 + (i + 1) * 0.1), z), verts=tmp.verts)
        merge(wood, tmp)
    # Seat height to match the part-built bench (slats 1.6 above the pavement, backs at 2.1 and 2.6).
    for bm in (iron, wood):
        bmesh.ops.scale(bm, vec=(1, 1, 0.8), verts=bm.verts)
    return model("Bench", {"Iron": iron, "Paint": wood})


def hydrant():
    red = bmesh.new()
    add_lathe(red, [(0.0, 0.0), (0.62, 0.0), (0.62, 0.18), (0.48, 0.3), (0.42, 0.35), (0.42, 1.9), (0.5, 2.0), (0.5, 2.15),
                    (0.36, 2.3), (0.22, 2.55), (0.12, 2.75), (0.0, 2.78)], segments=20)
    for x in (-1, 1):
        add_cylinder(red, (x * 0.55, 0, 1.6), 0.2, 0.35, axis="X", segments=16, bevel=0.04)
    add_cylinder(red, (0, -0.55, 1.45), 0.26, 0.4, axis="Y", segments=16, bevel=0.05)
    chrome = bmesh.new()
    for x in (-1, 1):
        add_cylinder(chrome, (x * 0.76, 0, 1.6), 0.12, 0.1, axis="X", segments=6)
    add_cylinder(chrome, (0, -0.8, 1.45), 0.14, 0.12, axis="Y", segments=6)
    add_cylinder(chrome, (0, 0, 2.82), 0.09, 0.14, segments=5)
    return model("Hydrant", {"Red": red, "Chrome": chrome})


def bin_():
    iron = bmesh.new()
    prof = [(0.0, 0.0), (0.72, 0.0), (0.8, 0.12)]
    for k in range(9):
        z = 0.2 + k * 0.28
        prof += [(0.8, z), (0.84, z + 0.08), (0.8, z + 0.16)]
    prof += [(0.82, 2.75), (0.0, 2.75)]
    add_lathe(iron, prof, segments=24)
    add_lathe(iron, [(0.0, 0.0), (0.92, 0.0), (0.88, 0.14), (0.55, 0.32), (0.2, 0.38), (0.0, 0.38)], (0, 0, 2.75), segments=24)
    gold = bmesh.new()
    add_cylinder(gold, (0, 0, 2.1), 0.86, 0.3, segments=24)
    return model("Bin", {"Iron": iron, "Gold": gold})


# ------------------------------------------------------------------ props, round two --
#
# These match part-built props in Downtown.luau measure for measure, so they are written in
# Roblox's coordinates as that file gives them and turned into Blender's here:
# Roblox (x, y, z) is Blender (x, -z, y).

def rb(x, y, z):
    return (x, -z, y)


def rbs(sx, sy, sz):
    return (sx, sz, sy)


def rbox(bm, centre, size, rot_x=0.0, rot_y=0.0, bevel=0.0, rot_z=0.0):
    """A box placed as Downtown places it (Roblox centre and size; turned about Roblox Z, X,
    then Y)."""
    tmp = bmesh.new()
    add_box(tmp, (0, 0, 0), rbs(*size), bevel=bevel)
    if rot_z:
        # Roblox's +Z is Blender's -Y.
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(-math.radians(rot_z), 3, "Y"))
    if rot_x:
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.radians(rot_x), 3, "X"))
    if rot_y:
        # Roblox's +Y turn is Blender's +Z turn.
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.radians(rot_y), 3, "Z"))
    bmesh.ops.translate(tmp, vec=Vector(rb(*centre)), verts=tmp.verts)
    merge(bm, tmp)


OCT = 1 / math.cos(math.pi / 8)


def add_octagon(bm, profile, closed=False):
    """An eight-sided lathe with flat faces toward the axes, from an (apothem, z) profile."""
    pts = [(a * OCT, z) for a, z in profile]
    if closed:
        pts.append(pts[0])
    tmp = bmesh.new()
    add_lathe(tmp, pts, segments=8)
    bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.pi / 8, 3, "Z"))
    merge(bm, tmp)


def ring(bm, profile, centre=(0, 0, 0), segments=32):
    """A lathe of a closed profile that does not touch the axis (lips, rims, collars)."""
    add_lathe(bm, profile + [profile[0]], centre, segments=segments)


def fountain():
    """The plaza's three-tier fountain: an octagonal pool with a moulded coping, a pedestal,
    a wide bowl, a slim stem, a small bowl and a finial, eight spouts round it."""
    stone, trim, water = bmesh.new(), bmesh.new(), bmesh.new()
    add_octagon(stone, [(0, 0), (12.95, 0), (12.95, 0.3), (12.8, 0.45), (12.8, 2.2), (11.2, 2.2), (11.2, 0.6), (0, 0.6)])
    add_octagon(trim, [(10.95, 2.2), (13.05, 2.2), (13.15, 2.32), (13.05, 2.5), (10.95, 2.5), (10.85, 2.35)], closed=True)
    add_lathe(stone, [(0, 0.6), (2.0, 0.6), (2.0, 1.0), (1.7, 1.15), (1.4, 1.5), (1.35, 4.3), (1.6, 4.55), (2.0, 4.95),
                      (0, 4.95)], segments=24)
    add_lathe(stone, [(0, 4.9), (1.9, 4.9), (3.3, 5.12), (4.4, 5.45), (5.0, 5.85), (5.15, 6.15), (4.7, 6.15), (0, 6.15)],
              segments=32)
    ring(trim, [(4.62, 6.1), (5.25, 6.1), (5.32, 6.28), (5.12, 6.42), (4.7, 6.38), (4.58, 6.22)])
    add_lathe(stone, [(0, 6.1), (1.1, 6.1), (0.8, 6.5), (0.6, 7.3), (0.7, 8.2), (1.25, 8.85), (0, 8.85)], segments=20)
    add_lathe(stone, [(0, 8.8), (1.3, 8.8), (2.2, 9.05), (2.75, 9.45), (2.85, 9.7), (0, 9.7)], segments=28)
    ring(trim, [(2.42, 9.65), (2.95, 9.65), (3.0, 9.8), (2.82, 9.9), (2.5, 9.86), (2.4, 9.75)])
    add_lathe(trim, [(0, 9.7), (0.75, 9.7), (0.6, 9.85), (0.3, 9.95), (0.28, 10.1), (0, 10.1)], segments=16)
    add_sphere(trim, (0, 0, 10.5), 0.5, subdiv=2)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        add_lathe(trim, [(0, 0.6), (0.7, 0.6), (0.6, 0.9), (0.42, 1.45), (0.6, 1.65), (0.5, 1.8), (0, 1.8)],
                  rb(math.cos(a) * 8, 0, math.sin(a) * 8), segments=12)
    add_octagon(water, [(0, 1.2), (11.25, 1.2), (11.25, 1.38), (0, 1.38)])
    add_lathe(water, [(0, 6.12), (4.75, 6.12), (4.75, 6.27), (0, 6.27)], segments=32)
    add_lathe(water, [(0, 9.66), (2.5, 9.66), (2.5, 9.8), (0, 9.8)], segments=24)
    return model("Fountain", {"Stone": stone, "Trim": trim, "Water": water})


def traffic_light():
    """trafficLight(): a pole with a mast arm over the road (-X), the signal head at its end lit
    on both faces, a crossing signal on the pole, the street-name blades on top. Standing on
    the kerb (Roblox y 0.5 is Blender z 0)."""
    pole, head, red, amber, green, blade, walk = (bmesh.new() for _ in range(7))
    k = -0.5                                      # Roblox heights to the kerb's
    add_lathe(pole, [(0, 0), (0.75, 0), (0.75, 0.55), (0.55, 0.75), (0.32, 0.95), (0, 0.95)], segments=16)
    add_cylinder(pole, (0, 0, 7.9), 0.28, 14.2, segments=16, radius2=0.23)
    add_sphere(pole, (0, 0, 15.05), 0.27, subdiv=2)
    hx = -8.2
    add_tube(pole, [(0, 0, 14.1), (-2.5, 0, 14.25), (hx + 0.3, 0, 14.25)], 0.19, segments=10)
    add_tube(pole, [(0, 0, 12.0), (-3.5, 0, 14.1)], 0.09, segments=8)
    rbox(pole, (hx, 14.2 + k, 0), (0.3, 0.5, 0.3))
    rbox(head, (hx, 12.6 + k, 0), (1.2, 3.64, 1.1), bevel=0.08)
    rbox(pole, (hx, 12.6 + k, 0), (1.7, 3.95, 0.16), bevel=0.04)
    for z, bm in ((13.7, red), (12.6, amber), (11.5, green)):
        for face in (-1, 1):
            add_cylinder(bm, rb(hx, z + k, face * 0.6), 0.4, 0.12, axis="Y", segments=20)
            # A hood over each lamp: a top and two cheeks.
            rbox(pole, (hx, z + k + 0.48, face * 0.86), (0.98, 0.08, 0.52))
            for x in (-0.47, 0.47):
                rbox(pole, (hx + x, z + k + 0.2, face * 0.86), (0.06, 0.62, 0.52))
    rbox(pole, (0, 8.4 + k, 0.72), (0.9, 1.3, 0.9), bevel=0.06)
    add_cylinder(walk, rb(0, 8.4 + k, 1.18), 0.33, 0.08, axis="Y", segments=16)
    rbox(head, (0.35, 4 + k, 0.4), (0.4, 0.6, 0.3), bevel=0.05)
    add_cylinder(pole, (0, 0, 16.1), 0.13, 2.7, segments=10)
    rbox(blade, (-2, 16.2 + k, 0), (5.2, 0.9, 0.14), bevel=0.03)
    rbox(blade, (0, 17.2 + k, -2), (0.14, 0.9, 5.2), bevel=0.03)
    return model("TrafficLight", {"Pole": pole, "Head": head, "SignalRed": red, "SignalAmber": amber,
                                  "SignalGreen": green, "Blade": blade, "WalkLamp": walk})


def dumpster():
    """dumpster(): a wheeled skip, wider at the top, ribbed, one lid shut and one thrown back."""
    body, lid, trim, wheel = (bmesh.new() for _ in range(4))
    add_profile(body, [(-1.55, 0.42), (1.55, 0.42), (1.72, 4.0), (-1.72, 4.0)], -3.0, 3.0, bevel=0.08)
    for x in (-1.2, 1.2):
        rbox(trim, (x, 2.2, -1.67), (0.24, 3.0, 0.12), rot_x=-2.7)
        rbox(trim, (x, 2.2, 1.67), (0.24, 3.0, 0.12), rot_x=2.7)
    rbox(trim, (0, 4.05, 0), (6.24, 0.3, 3.62), bevel=0.06)
    for x in (-2.4, 2.4):
        rbox(trim, (x, 2.4, -1.8), (1.2, 0.8, 0.25), bevel=0.04)
        for z in (-1.3, 1.3):
            add_cylinder(wheel, rb(x, 0.4, z), 0.4, 0.36, axis="X", segments=14)
            rbox(trim, (x, 0.75, z), (0.5, 0.3, 0.5))
    rbox(lid, (-1.5, 4.35, 0.1), (2.95, 0.2, 3.7), rot_x=-6, bevel=0.05)
    rbox(lid, (1.5, 4.9, 1.2), (2.95, 0.2, 3.7), rot_x=-58, bevel=0.05)
    return model("Dumpster", {"Body": body, "Lid": lid, "Trim": trim, "Wheel": wheel})


def phone_booth():
    """phoneBooth(): a red kiosk, its door toward Roblox -Z: corner posts, small-paned glass on
    three sides, a PHONE band, a stepped roof and a shallow dome."""
    red, glass, band = bmesh.new(), bmesh.new(), bmesh.new()
    rbox(red, (0, 0.15, 0), (3.3, 0.3, 3.3), bevel=0.04)
    for x in (-1.35, 1.35):
        for z in (-1.35, 1.35):
            rbox(red, (x, 3.85, z), (0.36, 7.1, 0.36), bevel=0.04)
    rbox(red, (0, 3.9, 1.42), (2.4, 6.6, 0.16))
    rbox(band, (0, 3.6, 1.32), (0.9, 1.3, 0.2), bevel=0.05)             # the phone, on the back wall
    for fx, fz in ((0, -1), (1, 0), (-1, 0)):
        along = (1, 0) if fz else (0, 1)
        def at(u, y, depth=1.46):
            return (fx * depth + along[0] * u, y, fz * depth + along[1] * u)
        def size(w, h, t):
            return (w, h, t) if fz else (t, h, w)
        rbox(glass, at(0, 3.85, 1.47), size(2.36, 4.5, 0.05))
        rbox(red, at(0, 1.0, 1.46), size(2.4, 1.1, 0.14))                # kick panel
        for u in (-0.4, 0.4):
            rbox(red, at(u, 3.85, 1.5), size(0.07, 4.5, 0.06))
        for k in range(1, 6):
            rbox(red, at(0, 1.6 + k * 0.75, 1.5), size(2.36, 0.07, 0.06))
        rbox(band, at(0, 6.9, 1.53), size(2.4, 0.6, 0.14))
    rbox(red, (0, 7.85, 0), (3.4, 0.5, 3.4), bevel=0.08)
    rbox(red, (0, 8.15, 0), (3.0, 0.16, 3.0), bevel=0.05)
    add_lathe(red, [(0, 8.2), (1.35, 8.2), (1.25, 8.4), (0.95, 8.6), (0.5, 8.72), (0, 8.75)], segments=24)
    add_sphere(red, (0, 0, 8.85), 0.18, subdiv=1)
    return model("PhoneBooth", {"Red": red, "Glass": glass, "Band": band})


def square_lathe(bm, profile):
    """A four-sided lathe, square to the axes: (corner radius, z) profile."""
    tmp = bmesh.new()
    add_lathe(tmp, profile, segments=4)
    bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.pi / 4, 3, "Z"))
    merge(bm, tmp)


def post_lamp():
    """postLamp(): a short plaza lamp, a four-sided lantern on a fluted post. On the paving
    (Roblox y 0.5 is Blender z 0)."""
    iron, glass = bmesh.new(), bmesh.new()
    add_lathe(iron, [(0, 0), (0.75, 0), (0.75, 0.25), (0.6, 0.4), (0.6, 0.85), (0.42, 1.0), (0.3, 1.2), (0, 1.2)],
              segments=12)
    add_cylinder(iron, (0, 0, 4.6), 0.22, 7.0, segments=12, radius2=0.18)
    for z in (2.0, 7.4):
        add_cylinder(iron, (0, 0, z), 0.3, 0.18, segments=12, bevel=0.04)
    square_lathe(iron, [(0, 7.9), (0.35, 7.9), (0.7, 8.1), (1.0, 8.18), (1.0, 8.3), (0, 8.3)])
    # The lantern: glass panes leaning out a little, iron corners, a pyramid cap and a finial.
    rb_, rt_ = 0.8, 1.0
    square_lathe(glass, [(0, 8.3), (rb_, 8.3), (rt_, 9.8), (0, 9.8)])
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        add_tube(iron, [(math.cos(a) * rb_, math.sin(a) * rb_, 8.3), (math.cos(a) * rt_, math.sin(a) * rt_, 9.8)], 0.06,
                 segments=6)
    square_lathe(iron, [(0, 9.75), (1.27, 9.75), (1.27, 9.9), (0.4, 10.45), (0, 10.5)])
    add_sphere(iron, (0, 0, 10.62), 0.16, subdiv=1)
    return model("PostLamp", {"Iron": iron, "LanternGlass": glass})


def cypress():
    """A slim cypress 10.5 tall (scaled to each one's height): a short trunk, then a lumpy
    flame of dark foliage, lighter toward the tip."""
    trunk = bmesh.new()
    add_cylinder(trunk, (0, 0, 1.2), 0.38, 2.4, segments=10, radius2=0.3)
    shades = {"Leaves1": bmesh.new(), "Leaves2": bmesh.new(), "Leaves3": bmesh.new()}
    rng = random.Random(11)
    for k in range(22):
        t = k / 21
        z = 2.4 + t * 7.6
        w = 1.55 * (1 - t * 0.78) * rng.uniform(0.85, 1.05)
        a = k * 2.4
        off = w * 0.28
        role = "Leaves1" if t < 0.4 else ("Leaves2" if t < 0.75 else "Leaves3")
        add_sphere(shades[role], (math.cos(a) * off, math.sin(a) * off, z), w, subdiv=2, squash=1.5, noise=0.14)
    add_sphere(shades["Leaves3"], (0, 0, 10.2), 0.35, subdiv=1, squash=1.8)
    return model("Cypress", {"Trunk": trunk, **shades})


def shrub():
    """A round flowering shrub 2.2 across (scaled to each): lumpy clumps of leaves, two
    greens, flowers dotted over the top."""
    dark, light, bloom = bmesh.new(), bmesh.new(), bmesh.new()
    rng = random.Random(5)
    add_sphere(dark, (0, 0, 0.85), 1.05, subdiv=2, squash=0.82, noise=0.14)
    for k in range(6):
        a = k * 1.05
        add_sphere(dark if k % 2 else light, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.72 + rng.uniform(-0.1, 0.15)),
                   rng.uniform(0.55, 0.72), subdiv=2, squash=0.85, noise=0.16)
    add_sphere(light, (0.2, -0.1, 1.45), 0.6, subdiv=2, squash=0.8, noise=0.15)
    for k in range(11):
        a = k * 2.39996
        rr = 0.25 + 0.7 * math.sqrt((k + 0.5) / 11)
        z = 0.85 + math.sqrt(max(0.0, 1.05 ** 2 - rr ** 2)) * 0.82 + 0.06
        add_sphere(bloom, (math.cos(a) * rr, math.sin(a) * rr, z), 0.17, subdiv=1)
    return model("Shrub", {"Leaves1": dark, "Leaves2": light, "Bloom": bloom})


# ----------------------------------------------------------------------- Hanami City --

def sakura():
    """A cherry tree in bloom (Hanami's CityKit.Sakura at scale 1): a short gnarled trunk that
    forks into three limbs, and a wide umbrella of blossom in three pinks, deepest underneath."""
    trunk = bmesh.new()
    add_cylinder(trunk, (0, 0, 2.4), 0.62, 4.8, segments=10, radius2=0.45)
    add_cylinder(trunk, (0, 0, 0.35), 0.9, 0.7, segments=10, radius2=0.62)
    for k in range(3):
        a = k * 2.1 + 0.3
        mid = (math.cos(a) * 1.4, math.sin(a) * 1.4, 6.2)
        tip = (math.cos(a) * 3.6, math.sin(a) * 3.6, 8.0)
        add_tube(trunk, [(0, 0, 4.4), mid, tip], 0.32, segments=8)
        add_tube(trunk, [mid, (math.cos(a + 0.7) * 2.6, math.sin(a + 0.7) * 2.6, 7.6)], 0.18, segments=6)
    shades = {"Blossom1": bmesh.new(), "Blossom2": bmesh.new(), "Blossom3": bmesh.new()}
    rng = random.Random(23)
    tiers = ((10, 4.6, 7.4, (2.4, 3.1), "Blossom1"), (8, 3.2, 9.0, (2.6, 3.2), "Blossom2"),
             (5, 1.6, 10.4, (2.2, 2.8), "Blossom3"), (9, 6.2, 8.0, (1.4, 1.9), "Blossom2"))
    for count, ring_r, z0, (s0, s1), role in tiers:
        for k in range(count):
            a = k / count * math.pi * 2 + rng.uniform(-0.2, 0.2)
            rr = ring_r * rng.uniform(0.88, 1.08)
            add_sphere(shades[role], (math.cos(a) * rr, math.sin(a) * rr, z0 + rng.uniform(-0.4, 0.4)),
                       rng.uniform(s0, s1), subdiv=2, squash=0.66, noise=0.18)
    add_sphere(shades["Blossom3"], (0, 0, 11.0), 2.6, subdiv=2, squash=0.6, noise=0.12)
    return model("Sakura", {"Trunk": trunk, **shades})


def pine():
    """A cloud-pruned garden pine (CityKit.Pine at scale 1): a trunk leaning and kinking, flat
    lumpy pads of needles on short arms."""
    trunk = bmesh.new()
    path = [(0, 0, 0), (0.5, 0, 3.0), (0.2, 0, 6.0), (0.9, 0, 9.4)]
    add_tube(trunk, path, 0.5, segments=10)
    add_cylinder(trunk, (0, 0, 0.3), 0.8, 0.6, segments=10, radius2=0.5)
    pads = {"Pine1": bmesh.new(), "Pine2": bmesh.new()}
    spots = (((0.9, 0, 9.6), 3.4, "Pine1"), ((3.0, 0.6, 6.4), 2.5, "Pine2"), ((-2.6, -0.6, 7.6), 2.4, "Pine1"),
             ((1.2, 0.2, 11.3), 2.0, "Pine2"), ((0.4, 2.2, 5.2), 1.7, "Pine2"))
    for (x, y, z), size, role in spots:
        add_tube(trunk, [(0.4, 0, z - 0.6), (x * 0.8, y * 0.8, z - 0.25)], 0.16, segments=6)
        add_sphere(pads[role], (x, y, z), size, subdiv=2, squash=0.34, noise=0.2)
        add_sphere(pads[role], (x + size * 0.35, y - size * 0.2, z + 0.25), size * 0.55, subdiv=2, squash=0.4, noise=0.2)
    return model("Pine", {"Trunk": trunk, **pads})


def hexagon(bm, profile, centre=(0, 0, 0)):
    tmp = bmesh.new()
    add_lathe(tmp, profile, segments=6)
    bmesh.ops.translate(tmp, vec=Vector(centre), verts=tmp.verts)
    merge(bm, tmp)


def stone_lantern():
    """A tōrō (CityKit.StoneLantern at scale 1): a hexagonal base, a post, the fire box with its
    paper windows, a roof with upturned corners and the jewel on top."""
    stone, paper = bmesh.new(), bmesh.new()
    hexagon(stone, [(0, 0), (0.95, 0), (0.95, 0.35), (0.8, 0.5), (0.55, 0.62), (0, 0.62)])
    add_cylinder(stone, (0, 0, 1.75), 0.36, 2.3, segments=12, radius2=0.3)
    hexagon(stone, [(0, 2.7), (0.45, 2.7), (0.85, 2.85), (0.9, 3.0), (0, 3.0)])
    for k in range(6):
        a = k * math.pi / 3
        add_box(stone, (math.cos(a) * 0.62, math.sin(a) * 0.62, 3.45), (0.16, 0.16, 0.9))
    hexagon(paper, [(0, 3.0), (0.56, 3.0), (0.56, 3.9), (0, 3.9)])
    roof = bmesh.new()
    hexagon(roof, [(0, 3.85), (1.2, 3.85), (1.3, 3.98), (0.95, 4.25), (0.45, 4.45), (0, 4.5)])
    for v in roof.verts:
        rr = math.hypot(v.co.x, v.co.y)
        if rr > 1.15:
            v.co.z += 0.18          # the corners turn up
    merge(stone, roof)
    add_lathe(stone, [(0, 4.4), (0.25, 4.4), (0.3, 4.6), (0.22, 4.82), (0.08, 4.98), (0, 5.02)], segments=10)
    return model("StoneLantern", {"Stone": stone, "LanternGlass": paper})


def vending():
    """A drinks machine (CityKit.Vending): the cabinet, its lit window recessed in a frame (the
    window and the cans are the game's own), the buttons, the slot and the header. Front -Z
    (Blender +Y), the back on the origin's line."""
    body, trim, dark = bmesh.new(), bmesh.new(), bmesh.new()
    rbox(body, (0, 3.2, 1.1), (3.0, 6.4, 2.2), bevel=0.12)
    rbox(trim, (0, 4.5, 0.06), (2.85, 3.1, 0.12), bevel=0.04)           # the frame round the window
    rbox(dark, (0, 3.05, -0.1), (2.4, 0.22, 0.14), bevel=0.03)
    for k in range(6):
        rbox(trim, (-1.0 + k * 0.4, 3.05, -0.19), (0.22, 0.12, 0.06))
    rbox(dark, (0, 0.95, -0.06), (2.2, 0.8, 0.14), bevel=0.05)
    rbox(trim, (0.95, 2.2, -0.08), (0.35, 0.55, 0.12), bevel=0.03)        # the coin box
    rbox(trim, (0, 6.05, -0.06), (3.0, 0.62, 0.16), bevel=0.04)
    rbox(dark, (0, 0.12, 1.1), (3.1, 0.24, 2.3))
    return model("Vending", {"Body": body, "Trim": trim, "Dark": dark})


def add_profile_xz(bm, points_xz, y0, y1, bevel=0.0, segments=2):
    """A profile in Blender's X-Z plane (Roblox X-Y) extruded along Blender Y (Roblox -Z)."""
    tmp = bmesh.new()
    verts = [tmp.verts.new((x, y0, z)) for x, z in points_xz]
    face = tmp.faces.new(verts)
    res = bmesh.ops.extrude_face_region(tmp, geom=[face])
    moved = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(tmp, vec=(0, y1 - y0, 0), verts=moved)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if bevel > 0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=segments, affect="EDGES", profile=0.5,
                        clamp_overlap=True)
    merge(bm, tmp)


def food_truck():
    """foodTruck(): a street-food truck, its serving hatch toward Roblox -Z and its cab at -X:
    a rounded box body with a band round it, a cab with a raked windscreen, wheels in arches,
    the hatch with its counter under a striped awning with a scalloped edge, a roof vent."""
    stripe, glass, trim, white, tyre, rim, awn_a, awn_b, front, rear = (bmesh.new() for _ in range(10))
    # The box and the cab, each with its own wheel arch cut, then one piece.
    merged = bmesh.new()
    for shape, x in (("box", 4.2), ("cab", -5.4)):
        shell = bmesh.new()
        if shape == "box":
            rbox(shell, (1.5, 4, 0), (11, 6, 6), bevel=0.35)
        else:
            add_profile_xz(shell, [(-3.4, 1.0), (-7.5, 1.0), (-7.5, 3.4), (-7.05, 5.6), (-3.4, 5.6)], -2.9, 2.9, bevel=0.25)
        obj = mesh_object(f"FoodTruck_{shape}", shell)
        arch = bmesh.new()
        add_cylinder(arch, rb(x, 1.1, 0), 1.38, 7.2, axis="Y", segments=28)
        cut(obj, arch)
        tmp = bmesh.new()
        tmp.from_mesh(obj.data)
        merge(merged, tmp)
        bpy.data.objects.remove(obj)
    body = mesh_object("FoodTruck_BodyTmp", merged)
    rbox(stripe, (1.5, 2.2, 0), (11.08, 0.6, 6.08), bevel=0.3)
    add_profile_xz(glass, [(-7.56, 3.5), (-7.14, 5.35), (-7.05, 5.35), (-7.47, 3.5)], -2.55, 2.55)
    for z in (-2.93, 2.93):
        rbox(glass, (-5.4, 4.4, z), (2.6, 1.7, 0.1), bevel=0.04)
    for x in (-5.4, 4.2):
        for z in (-2.75, 2.75):
            add_cylinder(tyre, rb(x, 1.1, z), 1.1, 0.8, axis="Y", segments=22, bevel=0.15)
            add_cylinder(rim, rb(x, 1.1, z + (0.36 if z > 0 else -0.36)), 0.6, 0.12, axis="Y", segments=18)
            add_cylinder(rim, rb(x, 1.1, z + (0.42 if z > 0 else -0.42)), 0.2, 0.12, axis="Y", segments=10)
    for x in (-7.7, 7.2):
        rbox(trim, (x, 1.4, 0), (0.4, 0.7, 6), bevel=0.1)
    for z in (-2.2, 2.2):
        rbox(front, (-7.56, 2.5, z), (0.12, 0.55, 0.85), bevel=0.04)
        rbox(rear, (7.02, 2.6, z), (0.12, 0.5, 0.7), bevel=0.04)
    rbox(trim, (1.5, 4.9, -3.0), (6, 2.6, 0.1))                       # the open hatch
    rbox(white, (1.5, 3.5, -3.4), (6.4, 0.3, 1.0), bevel=0.05)        # the counter
    for k in range(6):
        bm = awn_a if k % 2 == 0 else awn_b
        x = -1.25 + k * 1.1
        rbox(bm, (x, 6.95, -3.95), (1.1, 0.08, 2.15), rot_x=-24)
        add_cylinder(bm, rb(x, 6.42, -4.92), 0.32, 0.06, axis="Y", segments=12)
    rbox(trim, (1.5, 7.35, -3.0), (6.8, 0.2, 0.25))                    # the awning's rail
    rbox(white, (4.6, 7.3, 1.4), (1.7, 0.6, 1.7), bevel=0.12)          # a roof vent
    for x in (-1.2, 4.2):
        rbox(trim, (x, 7.4, -0.2), (0.3, 1.2, 0.3))
    rbox(trim, (6.6, 1.3, -4.4), (0.3, 2.4, 1.8), rot_z=8, bevel=0.04)  # the menu board
    return model("FoodTruck", {"Body": body, "Stripe": stripe, "Glass": glass, "Trim": trim, "Counter": white,
                               "Tyre": tyre, "Rim": rim, "AwningA": awn_a, "AwningB": awn_b, "LampFront": front,
                               "LampRear": rear})


def cafe_table():
    """cafeTable() with three chairs: a pedestal table under an eight-panel umbrella with a
    scalloped valance, chairs turned to it."""
    iron, top, can_a, can_b, chair = (bmesh.new() for _ in range(5))
    add_lathe(iron, [(0, 0), (0.85, 0), (0.85, 0.12), (0.3, 0.3), (0.18, 0.4), (0, 0.4)], segments=16)
    add_cylinder(iron, (0, 0, 1.55), 0.16, 2.4, segments=10)
    add_lathe(top, [(0, 2.75), (1.72, 2.75), (1.75, 2.9), (1.7, 3.02), (0, 3.02)], segments=28)
    add_cylinder(top, (0, 0, 5.9), 0.09, 6.0, segments=8)
    for k in range(8):
        a0, a1 = k * math.pi / 4, (k + 1) * math.pi / 4
        bm = can_a if k % 2 == 0 else can_b
        tmp = bmesh.new()
        pts = [(0, 0, 8.85)] + [(math.cos(a) * 3.25, math.sin(a) * 3.25, 7.7) for a in (a0, (a0 + a1) / 2, a1)]
        vs = [tmp.verts.new(p) for p in pts]
        tmp.faces.new([vs[0], vs[1], vs[2]])
        tmp.faces.new([vs[0], vs[2], vs[3]])
        res = bmesh.ops.extrude_face_region(tmp, geom=list(tmp.faces))
        moved = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.translate(tmp, vec=(0, 0, -0.08), verts=moved)
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        merge(bm, tmp)
        # A scallop hanging from the rim, facing out.
        am = (a0 + a1) / 2
        tmp2 = bmesh.new()
        add_cylinder(tmp2, (0, 0, 0), 0.32, 0.04, axis="X", segments=12)
        bmesh.ops.rotate(tmp2, verts=tmp2.verts, matrix=Matrix.Rotation(am, 3, "Z"))
        bmesh.ops.translate(tmp2, vec=(math.cos(am) * 3.05, math.sin(am) * 3.05, 7.62), verts=tmp2.verts)
        merge(bm, tmp2)
    add_sphere(can_a, (0, 0, 9.0), 0.25, subdiv=1)
    for i in range(3):
        a = (i + 1) / 3 * math.pi * 2 + 0.4
        tmp = bmesh.new()
        rbox(tmp, (0, 1.5, 0), (1.4, 0.18, 1.4), bevel=0.05)
        rbox(tmp, (0, 2.3, 0.64), (1.4, 1.2, 0.14), rot_x=-6, bevel=0.05)
        for x in (-0.55, 0.55):
            for z in (-0.55, 0.55):
                add_cylinder(tmp, rb(x, 0.72, z), 0.06, 1.44, segments=6)
        bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(math.pi / 2 - a, 3, "Z"))
        bmesh.ops.translate(tmp, vec=Vector(rb(math.cos(a) * 2.7, 0, math.sin(a) * 2.7)), verts=tmp.verts)
        merge(chair, tmp)
    return model("CafeTable", {"Iron": iron, "Top": top, "CanopyA": can_a, "CanopyB": can_b, "Chair": chair})


def torii():
    """A torii (Hanami's CityKit.Torii at w 10, h 8 -- the game stretches it to each gate):
    tapering posts on black feet, the tie beam through them, the plaque strut, and the top
    beam curving up at its ends under a black cap."""
    red, black = bmesh.new(), bmesh.new()
    for x in (-5, 5):
        add_cylinder(red, (x, 0, 5.0), 0.62, 10.0, segments=16, radius2=0.52)
        add_cylinder(black, (x, 0, 0.6), 0.82, 1.2, segments=16, radius2=0.74)
    rbox(red, (0, 8, 0), (12.2, 0.55, 0.5), bevel=0.05)                  # the nuki
    rbox(red, (0, 9.05, 0), (0.55, 1.6, 0.4))                            # the gakuzuka
    rbox(black, (0, 9.1, -0.22), (1.3, 1.2, 0.08), bevel=0.03)           # its plaque
    # The kasagi: a beam along X whose ends sweep up, the cap over it.
    for bm, (y0, thick, depth, half) in ((red, (10.05, 0.66, 0.95, 7.2)), (black, (10.65, 0.45, 1.15, 7.5))):
        tmp = bmesh.new()
        n = 24
        prof = []
        for k in range(n + 1):
            x = -half + 2 * half * k / n
            lift = 0.55 * (abs(x) / half) ** 3
            prof.append((x, y0 + lift))
        top_pts = [(x, y + thick) for x, y in prof]
        verts = [(x, z) for x, z in prof] + [(x, z) for x, z in reversed(top_pts)]
        add_profile_xz(tmp, verts, -depth / 2, depth / 2)
        merge(bm, tmp)
    return model("Torii", {"Red": red, "Black": black})


def awning():
    """One stripe of a shop's awning (the game stretches it to each stripe's width): canvas
    curving down and out from the wall (Roblox +Z) to a valance with a scalloped edge. 2.4
    wide, 1.3 tall, 3.2 deep, like the wedge it stands in for."""
    fabric = bmesh.new()
    top, bottom = [], []
    n = 12
    for k in range(n + 1):
        t = k / n
        z = 1.6 - 3.1 * t
        y = 0.65 - 1.05 * t ** 1.6
        top.append((-z, y))                        # (Blender y, Blender z)
        bottom.append((-z, y - 0.08))
    add_profile(fabric, top + list(reversed(bottom)), -1.2, 1.2)
    add_box(fabric, (0, 1.52, -0.52), (2.4, 0.06, 0.26))
    for x in (-0.6, 0.6):
        add_cylinder(fabric, (x, 1.52, -0.62), 0.3, 0.06, axis="Y", segments=14)
    return model("Awning", {"Fabric": fabric})


# -------------------------------------------------------------------------- city life --

def pigeon():
    """A street pigeon about a stud long, facing +Y (Roblox -Z), feet on the origin. The
    wings are their own pieces, folded along the back; CityLife flaps them about their
    shoulders."""
    body, head, wing_l, wing_r, feet = (bmesh.new() for _ in range(5))
    add_sphere(body, (0, -0.05, 0.42), 0.3, subdiv=2, squash=0.95)
    for v in body.verts:
        v.co.y = (v.co.y + 0.05) * 1.75 - 0.05          # long and plump
        if v.co.y < -0.25:
            v.co.z += (v.co.y + 0.25) * -0.25            # the tail end rises a touch
    add_box(body, (0, -0.72, 0.5), (0.26, 0.38, 0.06), bevel=0.02)       # the tail fan
    add_sphere(head, (0, 0.42, 0.68), 0.17, subdiv=2)
    add_sphere(head, (0, 0.3, 0.56), 0.19, subdiv=1, squash=1.2)         # the neck, its sheen
    tmp = bmesh.new()
    bmesh.ops.create_cone(tmp, cap_ends=True, segments=6, radius1=0.045, radius2=0.0, depth=0.14)
    bmesh.ops.rotate(tmp, verts=tmp.verts, matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    bmesh.ops.translate(tmp, vec=(0, 0.6, 0.66), verts=tmp.verts)
    merge(feet, tmp)
    for x in (-0.08, 0.08):
        add_cylinder(feet, (x, 0.02, 0.1), 0.025, 0.24, segments=5)
        add_box(feet, (x, 0.07, 0.015), (0.06, 0.16, 0.03))
    for bm, side in ((wing_l, -1), (wing_r, 1)):
        # A folded wing: a long flat teardrop lying along the back from the shoulder.
        pts = [(0.0, 0.18), (0.12, 0.1), (0.17, -0.15), (0.14, -0.45), (0.06, -0.62), (0.0, -0.5), (-0.03, -0.1)]
        tmp = bmesh.new()
        verts = [tmp.verts.new((side * (0.2 + px), py, 0.62 - (0.18 - py) * 0.12)) for px, py in pts]
        face = tmp.faces.new(verts if side > 0 else list(reversed(verts)))
        res = bmesh.ops.extrude_face_region(tmp, geom=[face])
        moved = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.translate(tmp, vec=(0, 0, -0.05), verts=moved)
        merge(bm, tmp)
    return model("Pigeon", {"Body": body, "Head": head, "WingL": wing_l, "WingR": wing_r, "Feet": feet})


# ------------------------------------------------------------------------- build it all --

def build():
    reset()
    car("Sedan", L=10, W=4.6, r=1.05, axles=(-3.2, 3.2), belt=2.45, roof=3.6, cabin=(-1.6, 0.9, 1.95, -2.75), nose=3.1, tail=2.1)
    car("Hatch", L=8.2, W=4.4, r=1.0, axles=(-2.6, 2.6), belt=2.4, roof=3.7, cabin=(-3.0, 0.9, 1.95, -3.75), nose=2.1, tail=0.3)
    car("SUV", L=10.4, W=4.8, r=1.2, axles=(-3.4, 3.4), belt=2.85, roof=4.3, cabin=(-4.55, 1.6, 2.55, -4.85), nose=2.6, tail=0.3,
        ride=0.6, rails=True, spare=True)
    street_lamp()
    tree("Tree")
    tree("TreeTall", 1.15)
    bench()
    hydrant()
    bin_()
    car("MuscleCar", L=11.5, W=5, r=1.05, axles=(-3.4, 3.6), radii=(1.2, 1.05), belt=2.55, roof=3.85,
        cabin=(-2.9, 0.5, 1.75, -4.3), nose=4.2, tail=1.25, ride=0.5, arch=0.08, muscle=True)
    fountain()
    traffic_light()
    dumpster()
    phone_booth()
    post_lamp()
    cypress()
    shrub()
    sakura()
    pine()
    stone_lantern()
    vending()
    pigeon()
    food_truck()
    cafe_table()
    torii()
    awning()


def piece_frame(obj):
    """Centre a piece on its bounding box (world space), no rotation; return (size, centre) in
    Blender axes."""
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    assert len(obj.data.vertices) > 0, f"{obj.name} has no geometry"
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    lo = Vector((min(xs), min(ys), min(zs)))
    hi = Vector((max(xs), max(ys), max(zs)))
    centre = (lo + hi) / 2
    obj.data.transform(Matrix.Translation(-centre))
    obj.location = centre
    return hi - lo, centre


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def write_manifest(entries):
    lines = [
        "--!strict",
        "-- GENERATED by tools/models/build_kit.py -- do not edit by hand.",
        "--",
        "-- The city kit's pieces: for each model, each mesh piece's size and its centre's offset from",
        "-- the model's origin, in studs, in Roblox's frame (+Y up, the model facing -Z, origin on the",
        "-- ground). MeshKit and CityMeshes place the pieces by these, whatever scale they came in at.",
        "",
        "return {",
    ]
    for name, pieces in entries:
        lines.append(f"\t{name} = {{")
        for role, size, centre, count in pieces:
            # Blender (x, y, z) -> Roblox (x, z, -y).
            lines.append(f"\t\t{role} = {{ size = Vector3.new({size.x:.3f}, {size.z:.3f}, {size.y:.3f}), "
                         f"offset = Vector3.new({centre.x:.3f}, {centre.z:.3f}, {-centre.y:.3f}), tris = {count} }},")
        lines.append("\t},")
    lines.append("}")
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")


def q16(x):
    return max(-32767, min(32767, int(round(x * 32767))))


def q8(x):
    return max(-127, min(127, int(round(x * 127))))


def geometry(obj, size):
    """One piece as the game rebuilds it with EditableMesh: unique (position, normal) vertices
    in Roblox's frame, each position as a fraction of the piece's half-size (int16), each
    normal int8, then the triangles (uint16 indices, counter-clockwise from the outside).
    Returns (vertex count, triangle count, bytes)."""
    me = obj.data
    me.calc_loop_triangles()
    normals = me.corner_normals
    half = (max(size.x / 2, 1e-4), max(size.z / 2, 1e-4), max(size.y / 2, 1e-4))   # Roblox axes
    ids = {}
    pos, nrm, idx = bytearray(), bytearray(), bytearray()
    count = 0
    for tri in me.loop_triangles:
        corner = []
        for loop in tri.loops:
            v = me.vertices[me.loops[loop].vertex_index].co
            n = normals[loop].vector
            p = (q16(v.x / half[0]), q16(v.z / half[1]), q16(-v.y / half[2]))
            nn = (q8(n.x), q8(n.z), q8(-n.y))
            key = p + nn
            if key not in ids:
                ids[key] = len(ids)
                pos += struct.pack("<hhh", *p)
                nrm += struct.pack("<bbb", *nn)
            corner.append(ids[key])
        if len(set(corner)) == 3:
            idx += struct.pack("<HHH", *corner)
            count += 1
    assert len(ids) < 65536, obj.name
    return len(ids), count, bytes(pos + nrm + idx)


def signed_volume(obj):
    me = obj.data
    me.calc_loop_triangles()
    vol = 0.0
    for tri in me.loop_triangles:
        a, b, c = (me.vertices[i].co for i in tri.vertices)
        vol += a.dot(b.cross(c)) / 6
    return vol


def write_geometry(entries):
    lines = [
        "--!strict",
        "-- GENERATED by tools/models/build_kit.py -- do not edit by hand.",
        "--",
        "-- The city kit's meshes themselves, for CityMeshes (the client builds them with EditableMesh,",
        "-- so they need no upload). Per piece: `verts` and `tris`, and `data`: base64 of the vertex",
        "-- positions (int16 x3, a fraction of the piece's half-size, MeshKitData's `size`), their",
        "-- normals (int8 x3), then the triangles (uint16 x3, counter-clockwise seen from outside).",
        "",
        "return {",
    ]
    for name, pieces in entries:
        lines.append(f"\t{name} = {{")
        for role, verts, count, blob in pieces:
            text = base64.b64encode(blob).decode()
            wrapped = "\n".join(text[i:i + 120] for i in range(0, len(text), 120))
            lines.append(f"\t\t{role} = {{ verts = {verts}, tris = {count}, data = [[\n{wrapped}]] }},")
        lines.append("\t},")
    lines.append("}")
    with open(GEOMETRY, "w") as f:
        f.write("\n".join(lines) + "\n")


def render_previews(entries):
    prev = os.path.join(OUT, "previews")
    os.makedirs(prev, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 480
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.72, 0.85, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sun = link(bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    ground = bmesh.new()
    add_box(ground, (0, 0, -0.05), (80, 80, 0.1))
    g = mesh_object("Ground", ground)
    gm = bpy.data.materials.new("GroundMat")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.55, 0.56, 1)
    g.data.materials.append(gm)
    cam = link(bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")))
    scene.camera = cam
    only = os.environ.get("KIT_ONLY")    # e.g. KIT_ONLY=Sedan,SUV renders just those
    for name, (empty, objs) in MODELS.items():
        if only and name not in only.split(","):
            continue
        for other, (e2, o2) in MODELS.items():
            for o in o2:
                o.hide_render = other != name
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        centre = (lo + hi) / 2
        radius = (hi - lo).length / 2
        d = radius * 2.6
        cam.location = centre + Vector((d * 0.75, d * 0.8, d * 0.45))
        direction = centre - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 45
        scene.render.filepath = os.path.join(prev, f"{name}.png")
        bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        o.hide_render = False
    # The whole kit in one shot (previews/sheet.png): the street furniture on the kerb, the cars
    # parked along it, the trees behind.
    def lineup(filename, layout, turned, repaints, eye, target):
        """Several models in one shot: `layout` name -> (x, y[, yaw degrees]); the rest hidden."""
        home = {}
        for name, (empty, objs) in MODELS.items():
            for o in objs:
                o.hide_render = name not in layout
        for name, spot in layout.items():
            empty = MODELS[name][0]
            home[name] = empty.location.copy()
            empty.location = (spot[0], spot[1], 0)
            yaw = spot[2] if len(spot) > 2 else (-90 if name in turned else 0)
            empty.rotation_euler = (0, 0, math.radians(yaw))
        # Paints for the shot only (put back afterwards; the game paints them).
        repaint = {}
        for (obj_name, colour) in repaints:
            obj = bpy.data.objects[obj_name]
            repaint[obj] = obj.data.materials[0]
            mat = repaint[obj].copy()
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
            obj.data.materials[0] = mat
        bpy.context.view_layer.update()
        scene.render.resolution_x, scene.render.resolution_y = 1600, 900
        scene.cycles.samples = 96
        cam.location = eye
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 32
        scene.render.filepath = os.path.join(prev, filename)
        bpy.ops.render.render(write_still=True)
        for obj, mat in repaint.items():
            extra = obj.data.materials[0]
            obj.data.materials[0] = mat
            bpy.data.materials.remove(extra)
        for name, loc in home.items():
            MODELS[name][0].location = loc
            MODELS[name][0].rotation_euler = (0, 0, 0)
        for name, (empty, objs) in MODELS.items():
            for o in objs:
                o.hide_render = False
        bpy.context.view_layer.update()

    if not only:
        # The street: furniture on the kerb, the cars parked along it, the trees behind.
        lineup("sheet.png", {"Tree": (-14, -9), "TreeTall": (9, -10), "StreetLamp": (-2, -6.5), "Bench": (-8, -5.5),
                             "Bin": (3.5, -5.5), "Hydrant": (6.5, -5), "Sedan": (-13, 2), "Hatch": (0, 2), "SUV": (13, 2)},
               ("Sedan", "Hatch", "SUV"), (("Hatch_Body", (0.16, 0.36, 0.72)), ("SUV_Body", (0.16, 0.17, 0.19))),
               (22, 42, 21), (0, -3, 5.5))
        # The plaza: the fountain, its lamps, cypresses and shrubs, a phone box, a skip, a muscle car.
        lineup("sheet2.png", {"Fountain": (0, -4), "PostLamp": (-15, 6), "Cypress": (15, -14), "Shrub": (12, 8),
                              "PhoneBooth": (-17, -12, 30), "TrafficLight": (22, 2, 180), "Dumpster": (-24, 4, 20),
                              "MuscleCar": (6, 18, -100)},
               (), (("MuscleCar_Body", (0.8, 0.12, 0.1)), ("Dumpster_Body", (0.2, 0.45, 0.3))),
               (30, 56, 30), (0, -2, 4))
    bpy.data.objects.remove(g)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)


def main():
    os.makedirs(OUT, exist_ok=True)
    build()
    render_previews(None)
    entries, shapes = [], []
    for name, (empty, objs) in MODELS.items():
        pieces, geo = [], []
        for obj in objs:
            size, centre = piece_frame(obj)
            role = obj.name.split("_", 1)[1]
            pieces.append((role, size, centre, tris(obj)))
            if signed_volume(obj) < 0:
                print(f"WARNING {obj.name} is inside out")
            geo.append((role, *geometry(obj, size)))
        entries.append((name, pieces))
        shapes.append((name, geo))
    write_manifest(entries)
    write_geometry(shapes)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "CityKit.glb"), export_format="GLB", export_yup=True,
                              export_apply=True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "CityKit.fbx"), axis_forward="-Z", axis_up="Y",
                             apply_scale_options="FBX_SCALE_UNITS", bake_space_transform=True)
    total = 0
    for name, pieces in entries:
        n = sum(p[3] for p in pieces)
        total += n
        print(f"{name:10s} {len(pieces)} pieces, {n} triangles, worst piece {max(p[3] for p in pieces)}")
    print(f"total {total} triangles -> {OUT}")


main()
