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

import math
import os
import random
import sys

import bpy  # noqa: E402  (bpy first: bmesh and mathutils come with it)
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.join(ROOT, "assets", "models")
MANIFEST = os.path.join(ROOT, "src", "ServerScriptService", "DistrictService", "MeshKitData.luau")

# Preview colours per role (the game colours each piece itself; these are only for renders).
PREVIEW = {
    "Body": (0.80, 0.18, 0.16), "Glass": (0.10, 0.16, 0.24), "Chrome": (0.78, 0.79, 0.82), "Tyre": (0.05, 0.05, 0.06),
    "Rim": (0.70, 0.71, 0.74), "LampFront": (1.0, 0.97, 0.85), "LampRear": (0.75, 0.08, 0.08), "Trim": (0.10, 0.10, 0.12),
    "Iron": (0.16, 0.22, 0.20), "LanternGlass": (1.0, 0.92, 0.70), "Trunk": (0.36, 0.24, 0.16),
    "Leaves1": (0.16, 0.42, 0.16), "Leaves2": (0.28, 0.58, 0.22), "Leaves3": (0.48, 0.74, 0.30),
    "Paint": (0.55, 0.30, 0.80), "Red": (0.78, 0.16, 0.12), "Gold": (0.90, 0.66, 0.16), "Wood": (0.62, 0.42, 0.24),
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
        else:
            obj = mesh_object(f"{name}_{role}", bm)
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

def car(name, L, W, r, axles, belt, roof, cabin, nose, tail, ride=0.45, rails=False, spare=False):
    hl = L / 2
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
    for y in axles:
        add_cylinder(arches, (0, y, r), r + 0.14, W + 1, axis="X", segments=32)
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
        for y in axles:
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
    pieces = {"Body": body, "Glass": glass, "Chrome": chrome, "LampFront": front, "LampRear": rear, "Tyre": tyre, "Rim": rim,
              "Trim": pillars}
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


def piece_frame(obj):
    """Centre a piece on its bounding box (world space), no rotation; return (size, centre) in
    Blender axes."""
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
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
        "-- ground). MeshKit places imported MeshParts by these, whatever scale they came in at.",
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
    if not only:
        layout = {"Tree": (-14, -9), "TreeTall": (9, -10), "StreetLamp": (-2, -6.5), "Bench": (-8, -5.5),
                  "Bin": (3.5, -5.5), "Hydrant": (6.5, -5), "Sedan": (-13, 2), "Hatch": (0, 2), "SUV": (13, 2)}
        home = {}
        for name, (x, y) in layout.items():
            empty = MODELS[name][0]
            home[name] = empty.location.copy()
            empty.location = (x, y, 0)
            if name in ("Sedan", "Hatch", "SUV"):
                empty.rotation_euler = (0, 0, math.radians(-90))
        # Each car in its own paint for the shot (put back afterwards; the game paints them).
        repaint = {}
        for name, colour in (("Hatch", (0.16, 0.36, 0.72)), ("SUV", (0.16, 0.17, 0.19))):
            obj = bpy.data.objects[f"{name}_Body"]
            repaint[obj] = obj.data.materials[0]
            mat = repaint[obj].copy()
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
            obj.data.materials[0] = mat
        bpy.context.view_layer.update()
        scene.render.resolution_x, scene.render.resolution_y = 1600, 900
        scene.cycles.samples = 96
        cam.location = (22, 42, 21)
        cam.rotation_euler = (Vector((0, -3, 5.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 32
        scene.render.filepath = os.path.join(prev, "sheet.png")
        bpy.ops.render.render(write_still=True)
        for obj, mat in repaint.items():
            extra = obj.data.materials[0]
            obj.data.materials[0] = mat
            bpy.data.materials.remove(extra)
        for name, loc in home.items():
            MODELS[name][0].location = loc
            MODELS[name][0].rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
    bpy.data.objects.remove(g)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)


def main():
    os.makedirs(OUT, exist_ok=True)
    build()
    render_previews(None)
    entries = []
    for name, (empty, objs) in MODELS.items():
        pieces = []
        for obj in objs:
            size, centre = piece_frame(obj)
            role = obj.name.split("_", 1)[1]
            pieces.append((role, size, centre, tris(obj)))
        entries.append((name, pieces))
    write_manifest(entries)
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
