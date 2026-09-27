#!/usr/bin/env python3
"""Rebuild a procedurally-authored weapon GLB as Roblox parts, for a build patch to assemble.

Meshes cannot be uploaded from here, so every mesh in the file becomes one or more Parts at
its own size, place and angle, in the weapon's Handle space (bore down -Z, up +Y, the Handle
on the authored GripPoint):

  * bevelled boxes (most of an AR: rails, ribs, plates, levers)  -> one Block each;
  * cylinders and lathed rings (barrel, pins, turrets, the scope) -> one Cylinder each;
  * profiled extrusions (receivers, grip, curved magazine, stock, trigger guard) -> sliced
    across their profile into strips, each strip a Block with a Wedge on any sloped edge, so
    the silhouette is the authored one rather than its bounding box;
  * crystal shards -> a body and a two-wedge chisel tip along the shard's own axis;
  * crust nodules, energy veins, shimmer motes -> a Block, a Neon Block, a Neon Ball.

Looks come from the Dark Matter carbine already in the game, by authored material name, so the
two Dark Matter guns read as one family.

  python3 tools/weapons/convert_glb.py <weapon.glb> tools/weapons/Warden_DarkMatter.json \\
      --length 4.2 [--preview out/prev.json]

The output is read by tools/patches/070_mastery_weapons.luau at build time.
"""
import json
import math
import os
import re
import struct
import sys

import numpy as np

CT = {5126: "f4", 5123: "u2", 5125: "u4", 5121: "u1"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


# ------------------------------------------------------------------------ glTF --

def load(path):
    b = open(path, "rb").read()
    clen, = struct.unpack("<I", b[12:16])
    j = json.loads(b[20:20 + clen])
    off = 20 + clen
    blen, = struct.unpack("<I", b[off:off + 4])
    return j, b[off + 8:off + 8 + blen]


def accessor(j, binb, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = np.dtype("<" + CT[a["componentType"]])
    n = NC[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", dt.itemsize * n)
    if stride == dt.itemsize * n:
        return np.frombuffer(binb, dtype=dt, count=a["count"] * n, offset=start).reshape(a["count"], n).astype(float)
    out = np.zeros((a["count"], n))
    for k in range(a["count"]):
        out[k] = np.frombuffer(binb, dtype=dt, count=n, offset=start + k * stride)
    return out


def quat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def local_matrix(n):
    if "matrix" in n:
        return np.array(n["matrix"]).reshape(4, 4).T
    m = np.eye(4)
    m[:3, :3] = quat(n.get("rotation", [0, 0, 0, 1])) @ np.diag(n.get("scale", [1, 1, 1]))
    m[:3, 3] = n.get("translation", [0, 0, 0])
    return m


def world_matrices(j):
    nodes = j["nodes"]
    parent = [None] * len(nodes)
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    world = [None] * len(nodes)

    def get(i):
        if world[i] is None:
            m = local_matrix(nodes[i])
            world[i] = m if parent[i] is None else get(parent[i]) @ m
        return world[i]

    for i in range(len(nodes)):
        get(i)
    return world, parent


# ----------------------------------------------------------------------- looks --

def rgb(r, g, b):
    return [r / 255, g / 255, b / 255]


# Authored material name -> (Roblox material, colour, reflectance, transparency). The gun's
# materials are the carbine's own, read off its imported parts; the crystals are the carbine's
# three crystal looks.
LOOKS = {
    "DM_Obsidian": ("Metal", rgb(12, 13, 19), 0.2, 0),
    "DM_Inset": ("Metal", rgb(9, 10, 18), 0.06, 0),
    "DM_Gunmetal": ("Metal", rgb(25, 27, 38), 0.31, 0),
    "DM_Energy": ("Neon", rgb(90, 30, 150), 0, 0),
    "DM_EnergyDim": ("Neon", rgb(58, 20, 104), 0, 0),
    "DM_PolymerDark": ("SmoothPlastic", rgb(15, 16, 23), 0.02, 0),
    "DM_Rubber": ("SmoothPlastic", rgb(8, 8, 12), 0, 0),
    "DM_CrystalDeep": ("SmoothPlastic", rgb(22, 18, 58), 0.23, 0),
    "DM_CrystalMid": ("Glass", rgb(58, 35, 133), 0.19, 0),
    "DM_CrystalBright": ("Neon", rgb(122, 73, 232), 0, 0),
    "DM_CrystalCrust": ("SmoothPlastic", rgb(30, 23, 66), 0.15, 0),
}
MOTE = ("Neon", rgb(122, 73, 232), 0, 0)
# Shards taller than this (studs, once scaled) get a chisel tip; smaller ones are one piece.
SHARD_DETAIL = 0.24
LENS = ("Glass", rgb(140, 82, 242), 0.25, 0.6)

# Authored part name -> the name the game's systems look for (pose solver, reload, charge).
RENAME = {
    "BarrelTube": "Barrel",
    "MuzzleBore": "MuzzleTip",
    "OpticRailBase": "Rail",
    "GripBody": "Grip",
    "HandguardBody": "LowerHandguard",
    "ChargingHandleBody": "ChargingHandle",
    "MagBody": "Magazine",
    "MagFloorplate": "MagFloor",
    "StockBody": "Stock",
    "BoltCarrier": "Bolt",
}
DECOR = {"DarkMatterCrystals", "DarkMatterEnergy", "DarkMatterShimmer", "VFX", "AttachmentPoints"}


# ------------------------------------------------------------------- primitives --

class Part:
    """One Roblox part in GLB world space: class, shape, centre, axes (columns X Y Z), size."""

    def __init__(self, name, cls, shape, centre, axes, size, look, group, extra=None):
        self.name, self.cls, self.shape = name, cls, shape
        self.centre, self.axes, self.size = np.asarray(centre, float), np.asarray(axes, float), np.asarray(size, float)
        self.look, self.group, self.extra = look, group, extra or {}


def orthonormal(m):
    """Nearest rotation to m (columns), and the scale along each column."""
    s = np.linalg.norm(m, axis=0)
    r = m / s
    u, _, vt = np.linalg.svd(r)
    r = u @ vt
    if np.linalg.det(r) < 0:
        r[:, 2] *= -1
    return r, s


def block(name, lo, hi, L, t, look, group, cls="Part", shape="Block"):
    """A box spanning [lo, hi] in a node's local space, placed by its matrix (L, t)."""
    r, s = orthonormal(L)
    centre = L @ ((lo + hi) / 2) + t
    return Part(name, cls, shape, centre, r, (hi - lo) * s, look, group)


def wedge(name, right, along, up, thick_axis, thickness, look, group):
    """A right-triangle prism: `right` is the right-angle corner, `along` the far end of the
    leg that runs along the bottom, `up` the top of the vertical leg (all in world space).
    Roblox's wedge has its right angle at local (+Z, -Y): bottom leg toward -Z, back leg +Y."""
    zdir = right - along
    ydir = up - right
    sz, sy = np.linalg.norm(zdir), np.linalg.norm(ydir)
    if sz < 1e-6 or sy < 1e-6:
        return None
    zdir, ydir = zdir / sz, ydir / sy
    xdir = np.cross(ydir, zdir)
    n = np.linalg.norm(xdir)
    if n < 1e-6:
        return None
    xdir /= n
    centre = right + (along - right) / 2 + (up - right) / 2
    return Part(name, "WedgePart", "Wedge", centre, np.column_stack([xdir, ydir, zdir]),
                [thickness, sy, sz], look, group)


# ------------------------------------------------------------------ extrusions --

def projected_triangles(v2, tris):
    """The mesh's triangles projected onto the profile plane, degenerate ones dropped."""
    out = []
    for a, b, c in tris:
        p = v2[[a, b, c]]
        area = (p[1, 0] - p[0, 0]) * (p[2, 1] - p[0, 1]) - (p[2, 0] - p[0, 0]) * (p[1, 1] - p[0, 1])
        if abs(area) > 1e-12:
            out.append(p)
    return np.array(out)


def intervals_at(tri2, u, gap):
    """Where the line x = u crosses the profile: merged [lo, hi] intervals in y."""
    spans = []
    for p in tri2:
        ys = []
        for i in range(3):
            a, b = p[i], p[(i + 1) % 3]
            if (a[0] - u) * (b[0] - u) <= 0 and a[0] != b[0]:
                k = (u - a[0]) / (b[0] - a[0])
                ys.append(a[1] + k * (b[1] - a[1]))
            elif a[0] == u:
                ys.append(a[1])
        if len(ys) >= 2:
            spans.append((min(ys), max(ys)))
    spans.sort()
    merged = []
    for lo, hi in spans:
        if merged and lo <= merged[-1][1] + gap:
            merged[-1][1] = max(merged[-1][1], hi)
        else:
            merged.append([lo, hi])
    return [m for m in merged if m[1] - m[0] > gap]


def slice_profile(tri2, cuts, tol, gap):
    """Strips across the profile, each linear enough that a block and two wedges fill it."""
    umin, umax = cuts[0], cuts[-1]
    strips = []
    eps = (umax - umin) * 1e-4

    def ok(u0, u1):
        a = intervals_at(tri2, u0 + eps, gap)
        b = intervals_at(tri2, u1 - eps, gap)
        m = intervals_at(tri2, (u0 + u1) / 2, gap)
        if len(a) != len(b) or len(a) != len(m):
            return None
        for (alo, ahi), (blo, bhi), (mlo, mhi) in zip(a, b, m):
            if abs((alo + blo) / 2 - mlo) > tol or abs((ahi + bhi) / 2 - mhi) > tol:
                return None
        return a, b

    def split(u0, u1, depth):
        res = ok(u0, u1)
        if res is not None or depth > 12 or u1 - u0 < (umax - umin) * 0.004:
            if res is None:
                mid = intervals_at(tri2, (u0 + u1) / 2, gap)
                res = (mid, mid)
            strips.append((u0, u1, res))
            return
        inner = [c for c in cuts if u0 + eps < c < u1 - eps]
        mid = (u0 + u1) / 2
        c = min(inner, key=lambda x: abs(x - mid)) if inner else mid
        split(u0, c, depth + 1)
        split(c, u1, depth + 1)

    split(umin, umax, 0)
    return strips


def extrusion_parts(name, v, tris, L, t, axis, look, group, tol):
    """Slice a profiled extrusion (node-local verts v, extruded along local `axis`)."""
    lo, hi = v.min(0), v.max(0)
    others = [k for k in range(3) if k != axis]
    best = None
    for iu, iv in (others, others[::-1]):
        v2 = v[:, [iu, iv]]
        tri2 = projected_triangles(v2, tris)
        cuts = np.unique(np.round(v2[:, 0], 5))
        # Collapse cuts closer together than the tolerance: they buy nothing visible.
        kept = [cuts[0]]
        for c in cuts[1:]:
            if c - kept[-1] > tol:
                kept.append(c)
        if kept[-1] != cuts[-1]:
            kept[-1] = cuts[-1]
        strips = slice_profile(tri2, kept, tol, tol * 0.5)
        parts = []
        for (u0, u1, (a, b)) in strips:
            for (alo, ahi), (blo, bhi) in zip(a, b):
                parts.extend(strip_parts(name, u0, u1, alo, ahi, blo, bhi, iu, iv, axis, lo, hi, L, t, look, group, tol))
        if best is None or len(parts) < len(best):
            best = parts
    return best


def strip_parts(name, u0, u1, alo, ahi, blo, bhi, iu, iv, axis, lo, hi, L, t, look, group, tol):
    out = []

    def point(u, w):
        p = np.zeros(3)
        p[iu], p[iv], p[axis] = u, w, (lo[axis] + hi[axis]) / 2
        return L @ p + t

    r, s = orthonormal(L)
    thickness = (hi[axis] - lo[axis]) * s[axis]
    core_lo, core_hi = max(alo, blo), min(ahi, bhi)
    if core_hi - core_lo > 1e-6:
        clo = np.zeros(3)
        chi = np.zeros(3)
        clo[iu], clo[iv], clo[axis] = u0, core_lo, lo[axis]
        chi[iu], chi[iv], chi[axis] = u1, core_hi, hi[axis]
        out.append(block(name, clo, chi, L, t, look, group))
    else:
        core_lo = core_hi = (max(alo, blo) + min(ahi, bhi)) / 2
    # Top edge: from the core's top up to whichever end is higher.
    if abs(ahi - bhi) > tol * 0.25:
        if ahi > bhi:
            w = wedge(name, point(u0, core_hi), point(u1, core_hi), point(u0, ahi), axis, thickness, look, group)
        else:
            w = wedge(name, point(u1, core_hi), point(u0, core_hi), point(u1, bhi), axis, thickness, look, group)
        if w:
            out.append(w)
    # Bottom edge: from the core's bottom down to whichever end is lower.
    if abs(alo - blo) > tol * 0.25:
        if alo < blo:
            w = wedge(name, point(u0, core_lo), point(u1, core_lo), point(u0, alo), axis, thickness, look, group)
        else:
            w = wedge(name, point(u1, core_lo), point(u0, core_lo), point(u1, blo), axis, thickness, look, group)
        if w:
            out.append(w)
    return out


def extrusion_axis(v, tol):
    """The local axis a profiled extrusion runs along: every vertex sits within a bevel of one
    of its two end planes. None if the mesh is not an extrusion."""
    lo, hi = v.min(0), v.max(0)
    best = None
    for k in range(3):
        near = (np.abs(v[:, k] - lo[k]) < tol) | (np.abs(v[:, k] - hi[k]) < tol)
        frac = near.mean()
        if frac > 0.97 and (best is None or hi[k] - lo[k] < hi[best] - lo[best]):
            best = k
    return best


def profile_fill(v, tris, axis):
    """How much of its bounding rectangle the profile covers: near 1 for a (rounded) box."""
    lo, hi = v.min(0), v.max(0)
    iu, iv = [k for k in range(3) if k != axis]
    tri2 = projected_triangles(v[:, [iu, iv]], tris)
    area = 0.0
    n = 24
    for k in range(n):
        u = lo[iu] + (hi[iu] - lo[iu]) * (k + 0.5) / n
        area += sum(b - a for a, b in intervals_at(tri2, u, 1e-9))
    return area / n / max(hi[iv] - lo[iv], 1e-12)


def ring_parts(name, c, k, o, a0, a1, rmin, rmax, L, t, look, group, sides=8):
    """An open ring about local axis k: `sides` flat slats round it."""
    out = []
    r, s = orthonormal(L)
    mid = (rmin + rmax) / 2
    width = 2 * rmax * math.tan(math.pi / sides) * 1.04
    for i in range(sides):
        ang = 2 * math.pi * i / sides
        radial = np.zeros(3)
        radial[o[0]], radial[o[1]] = math.cos(ang), math.sin(ang)
        tangent = np.zeros(3)
        tangent[o[0]], tangent[o[1]] = -math.sin(ang), math.cos(ang)
        axis = np.zeros(3)
        axis[k] = 1
        centre_local = c.copy()
        centre_local[k] = (a0 + a1) / 2
        centre_local = centre_local + radial * mid
        # Local frame of the slat: X along the ring's axis, Y out from it, Z round it.
        frame = np.column_stack([L @ axis, L @ radial, L @ tangent])
        frame = frame / np.linalg.norm(frame, axis=0)
        if np.linalg.det(frame) < 0:
            frame[:, 2] *= -1
        size = np.array([(a1 - a0) * np.linalg.norm(L @ axis), (rmax - rmin) * np.linalg.norm(L @ radial),
                         width * np.linalg.norm(L @ tangent)])
        out.append(Part(name, "Part", "Block", L @ centre_local + t, frame, size, look, group))
    return out


# ---------------------------------------------------------------------- shards --

def shard_parts(name, v, L, t, look, group, detail_height):
    """A crystal shard, authored along its local +Y: a body up to the top ring, then a chisel
    tip of two wedges to the point. A shard too small for the tip to show (most of them are
    well under a tenth of a stud) is its body alone, run to the point."""
    lo, hi = v.min(0), v.max(0)
    r0, s0 = orthonormal(L)
    if (hi[1] - lo[1]) * s0[1] < detail_height:
        radial = np.sqrt(v[:, 0] ** 2 + v[:, 2] ** 2)
        width = 2 * radial.max() * 0.7
        cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
        return [block(name, np.array([cx - width / 2, lo[1], cz - width / 2]),
                      np.array([cx + width / 2, hi[1] - (hi[1] - lo[1]) * 0.12, cz + width / 2]), L, t, look, group)]
    ys = np.unique(np.round(v[:, 1], 5))
    rings = [y for y in ys if (np.abs(v[:, 1] - y) < 1e-5).sum() >= 3]
    radial = np.sqrt(v[:, 0] ** 2 + v[:, 2] ** 2)
    width = 2 * radial.max() * 0.78
    top = max(rings) if rings else lo[1] + (hi[1] - lo[1]) * 0.7
    if top <= lo[1] + 1e-6 or top >= hi[1] - 1e-6:
        top = lo[1] + (hi[1] - lo[1]) * 0.7
    cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
    body = block(name, np.array([cx - width / 2, lo[1], cz - width / 2]),
                 np.array([cx + width / 2, top, cz + width / 2]), L, t, look, group)
    out = [body]
    r, s = orthonormal(L)
    thick = width * s[0]
    apex = hi[1]
    for side in (1, -1):
        right = L @ np.array([cx, top, cz]) + t
        along = L @ np.array([cx, top, cz + side * width / 2]) + t
        up = L @ np.array([cx, apex, cz]) + t
        w = wedge(name, right, along, up, 0, thick, look, group)
        if w:
            out.append(w)
    return out


# ------------------------------------------------------------------------- main --

def main():
    args = sys.argv[1:]
    preview = None
    length = 4.2
    if "--preview" in args:
        k = args.index("--preview")
        preview = args[k + 1]
        del args[k:k + 2]
    if "--length" in args:
        k = args.index("--length")
        length = float(args[k + 1])
        del args[k:k + 2]
    glb_path, out_path = args[0], args[1]

    j, binb = load(glb_path)
    world, parent = world_matrices(j)
    nodes = j["nodes"]
    mats = [m.get("name", "") for m in j.get("materials", [])]
    extras = nodes[0].get("extras", {}).get("parts", {})
    kinds = {}
    for grp, v in extras.items():
        geos = {g["uuid"]: g for g in v.get("geometries", [])}

        def walk(o):
            g = geos.get(o.get("geometry"))
            if g:
                kinds[o.get("name")] = g
            for c in o.get("children", []):
                walk(c)
        walk(v["object"])

    def group_of(i):
        chain = []
        k = i
        while k is not None:
            chain.append(nodes[k].get("name", ""))
            k = parent[k]
        # [..., group, "Weapon", root]; the shimmer sits one deeper, under VFX.
        if len(chain) >= 4 and chain[-3] == "VFX":
            return chain[-4]
        return chain[-3] if len(chain) >= 3 else chain[-1]

    # The scale is only known once the gun is measured; shards need it earlier, to decide
    # which are big enough for a tip. The gun's length along X is all it takes.
    gun_x = []
    for i, n in enumerate(nodes):
        if "mesh" in n and group_of(i) not in DECOR:
            prim = j["meshes"][n["mesh"]]["primitives"][0]
            a = j["accessors"][prim["attributes"]["POSITION"]]
            for corner in (a["min"], a["max"]):
                gun_x.append((world[i] @ np.array(list(corner) + [1.0]))[0])
    pre_scale = length / (max(gun_x) - min(gun_x))

    points = {}
    parts = []
    names_used = {}
    for i, n in enumerate(nodes):
        g = group_of(i)
        if g == "AttachmentPoints" and "mesh" not in n and n.get("name") != "AttachmentPoints":
            points[n["name"]] = world[i][:3, 3]
        if "mesh" not in n:
            continue
        prim = j["meshes"][n["mesh"]]["primitives"][0]
        mat = prim.get("material")
        mname = mats[mat] if mat is not None and mat < len(mats) else ""
        v = accessor(j, binb, prim["attributes"]["POSITION"])
        if "indices" in prim:
            tris = accessor(j, binb, prim["indices"]).astype(int).reshape(-1, 3)
        else:
            tris = np.arange(len(v)).reshape(-1, 3)
        L, t = world[i][:3, :3], world[i][:3, 3]
        name = RENAME.get(n["name"], n["name"])
        kind = kinds.get(n["name"], {}).get("type")
        look = LOOKS.get(mname)
        if g == "DarkMatterShimmer":
            alpha = j["materials"][mat]["pbrMetallicRoughness"].get("baseColorFactor", [1, 1, 1, 1])[3]
            lo, hi = v.min(0), v.max(0)
            r, s = orthonormal(L)
            d = float(np.mean((hi - lo) * s))
            look = (MOTE[0], MOTE[1], 0, round(1 - min(1, alpha * 1.6), 3))
            parts.append(Part(name, "Part", "Ball", L @ ((lo + hi) / 2) + t, r, [d, d, d], look, g))
            continue
        if look is None:
            look = LOOKS["DM_Obsidian"]
        if "Lens" in n["name"] or n["name"] in ("MagWindow",):
            look = LENS if "Lens" in n["name"] else look

        lo, hi = v.min(0), v.max(0)
        if g == "DarkMatterCrystals":
            if kind == "IcosahedronGeometry" or len(np.unique(np.round(v, 5), axis=0)) == 12:
                parts.append(block(name, lo, hi, L, t, look, g))
            else:
                parts.extend(shard_parts(name, v, L, t, look, g, SHARD_DETAIL / pre_scale))
            continue
        if g == "DarkMatterEnergy" or kind == "BoxGeometry":
            parts.append(block(name, lo, hi, L, t, look, g))
            continue
        if kind in ("CylinderGeometry", "LatheGeometry"):
            # Round about the local axis whose cross-section is round. Usually local Y, as
            # three.js builds them, but some were turned before export (the optic's hoods).
            ext = hi - lo
            k = 1
            for cand in (1, 0, 2):
                o = [x for x in range(3) if x != cand]
                if abs(ext[o[0]] - ext[o[1]]) <= 0.08 * ext[o].max():
                    k = cand
                    break
            o = [x for x in range(3) if x != k]
            c = (lo + hi) / 2
            rr = np.sqrt(((v[:, o] - c[o]) ** 2).sum(1))
            rmax = rr.max()
            rmin = rr[rr > rmax * 0.02].min() if (rr > rmax * 0.02).any() else 0
            if kind == "LatheGeometry" and rmin > 0.45 * rmax:
                # An open ring (a hood round a lens): an eight-sided band, so the lens shows.
                parts.extend(ring_parts(name, c, k, o, lo[k], hi[k], rmin, rmax, L, t, look, g))
                continue
            p = block(name, np.array([c[0] - rmax, c[1] - rmax, c[2] - rmax]),
                      np.array([c[0] + rmax, c[1] + rmax, c[2] + rmax]), L, t, look, g, shape="Cylinder")
            r, sc = orthonormal(L)
            order = [k, o[0], o[1]]
            if np.linalg.det(r[:, order]) < 0:
                order = [k, o[1], o[0]]
            p.axes = r[:, order]
            p.size = np.array([ext[k] * sc[k], 2 * rmax * sc[order[1]], 2 * rmax * sc[order[2]]])
            parts.append(p)
            continue
        if kind == "IcosahedronGeometry":
            p = block(name, lo, hi, L, t, look, g, shape="Ball")
            d = float(np.mean(p.size))
            p.size = np.array([d, d, d])
            parts.append(p)
            continue
        # A cylinder the extras do not describe (the receiver's pins, the barrel): round about
        # one local axis -- its rim vertices all at one radius and spread evenly round it. The
        # spread matters: a bevelled box with a square section has its corners at one radius
        # too, but bunched at four angles.
        round_axis = None
        for k in range(3):
            o = [x for x in range(3) if x != k]
            ext = (hi - lo)[o]
            if abs(ext[0] - ext[1]) > 0.1 * ext.max():
                continue
            c = (lo[o] + hi[o]) / 2
            d = v[:, o] - c
            rr = np.sqrt((d ** 2).sum(1))
            rim = rr > rr.max() * 0.5
            if rim.mean() < 0.5 or (rr[rim].max() - rr[rim].min()) > 0.08 * rr.max():
                continue
            ang = np.sort(np.unique(np.round(np.arctan2(d[rim, 1], d[rim, 0]), 3)))
            if len(ang) < 8:
                continue
            gaps = np.diff(np.concatenate([ang, [ang[0] + 2 * math.pi]]))
            if gaps.max() < 2 * math.pi / 6:
                round_axis = k
                break
        if round_axis is not None and kind != "ExtrudeGeometry":
            k = round_axis
            o = [x for x in range(3) if x != k]
            p = block(name, lo, hi, L, t, look, g, shape="Cylinder")
            ax = p.axes
            order = [k, o[0], o[1]]
            if np.linalg.det(ax[:, order]) < 0:
                order = [k, o[1], o[0]]
            p.axes = ax[:, order]
            p.size = p.size[order]
            parts.append(p)
            continue
        # Extrusions: a (rounded) box stays one Block; a real profile is sliced.
        tol_bevel = 0.0028
        axis = 2 if kind == "ExtrudeGeometry" else extrusion_axis(v, tol_bevel)
        if axis is not None:
            fill = profile_fill(v, tris, axis)
            # A rounded rectangle covers about 0.8-0.95 of its box; only a real profile (a
            # curved magazine, a stock, a trigger guard) is worth slicing.
            if fill < 0.8:
                size = float((hi - lo).max())
                # About two millimetres on a rifle: a few hundredths of a stud once scaled, which
                # is finer than anyone sees on a gun in someone's hands.
                tol = max(0.0018, size * 0.035)
                sliced = extrusion_parts(name, v, tris, L, t, axis, look, g, tol)
                while len(sliced) > 18 and tol < size * 0.25:
                    tol *= 1.4
                    sliced = extrusion_parts(name, v, tris, L, t, axis, look, g, tol)
                if sliced:
                    parts.extend(sliced)
                    continue
        parts.append(block(name, lo, hi, L, t, look, g))

    # ------------------------------------------------------------ Handle space --
    gun = [p for p in parts if p.group not in DECOR]
    xs = [p.centre[0] for p in gun]
    muzzle_point = points.get("MuzzlePoint")
    grip_point = points.get("GripPoint")
    # Bore along the file's +X (MuzzlePoint is at the +X end), up along +Y.
    bore = np.array([1.0, 0, 0]) if muzzle_point is None or muzzle_point[0] > np.mean(xs) else np.array([-1.0, 0, 0])
    up = np.array([0, 1.0, 0])
    right = np.cross(bore, up)
    # Rows: the file's vectors expressed on the Handle's X (right), Y (up), Z (back) axes.
    M = np.vstack([right, up, -bore])
    span_lo, span_hi = None, None
    for p in gun:
        ext = 0.5 * np.abs(p.axes * p.size).sum(1)
        a, b = p.centre - ext, p.centre + ext
        proj_lo, proj_hi = min(a @ bore, b @ bore), max(a @ bore, b @ bore)
        span_lo = proj_lo if span_lo is None else min(span_lo, proj_lo)
        span_hi = proj_hi if span_hi is None else max(span_hi, proj_hi)
    scale = length / (span_hi - span_lo)
    origin = grip_point if grip_point is not None else np.mean([p.centre for p in gun], 0)

    def to_handle(pt):
        return scale * (M @ (np.asarray(pt) - origin))

    out_parts = []
    # Every part a unique name: the reload finds the magazine's pieces by name, and a sliced
    # profile is several pieces. The biggest keeps the plain name the game looks for.
    order = sorted(range(len(parts)), key=lambda k: -float(np.prod(parts[k].size)))
    taken = set()
    final_name = [None] * len(parts)
    for k in order:
        base = parts[k].name
        nm = base
        idx = 1
        while nm in taken:
            idx += 1
            nm = f"{base}_{idx}"
        taken.add(nm)
        final_name[k] = nm
    for k, p in enumerate(parts):
        rot = M @ p.axes
        pos = to_handle(p.centre)
        mat, colour, refl, transp = p.look
        rec = {
            "n": final_name[k], "cls": p.cls, "s": p.shape,
            "z": [round(float(x) * scale, 5) for x in p.size],
            "cf": [round(float(x), 5) for x in pos] + [round(float(x), 6) for x in rot.flatten()],
            "m": mat, "c": [round(x, 4) for x in colour], "rf": refl, "t": transp,
            "g": p.group,
        }
        # The magazine, and what grows on it (its crystals and energy veins -- not the
        # magwell's, which belong to the receiver), leave together on a reload.
        if p.group == "Magazine" or (p.group in ("DarkMatterCrystals", "DarkMatterEnergy")
                                     and re.match(r"^(Fx)?Mag(?!well)", p.name)):
            rec["mag"] = True
        out_parts.append(rec)

    data = {
        "source": re.sub(r"^[0-9a-f]{8}-", "", os.path.basename(glb_path)),
        "scale": round(scale, 5),
        "length": length,
        "points": {k: [round(float(x), 5) for x in to_handle(v)] for k, v in points.items()},
        "parts": out_parts,
    }
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    by = {}
    for r in out_parts:
        by[r["g"]] = by.get(r["g"], 0) + 1
    print(f"{len(out_parts)} parts, scale {scale:.4f} (length {length})")
    for g, c in sorted(by.items(), key=lambda x: -x[1]):
        print(f"  {g:20s} {c}")
    if preview:
        # The file's own space, for tools/weapons/preview.mjs to draw over the original.
        prev = [{"name": p.name, "shape": p.shape, "cls": p.cls, "size": p.size.tolist(), "centre": p.centre.tolist(),
                 "axes": p.axes.tolist(), "colour": p.look[1], "material": p.look[0], "transparency": p.look[3]}
                for p in parts]
        with open(preview, "w") as f:
            json.dump({"glb": os.path.abspath(glb_path), "parts": prev}, f)


if __name__ == "__main__":
    main()
