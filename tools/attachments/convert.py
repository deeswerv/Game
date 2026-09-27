#!/usr/bin/env python3
"""Turn authored attachment GLBs into exact-fit parts for one weapon.

Each GLB is the whole weapon with ONE attachment fitted: the weapon's own groups (Receiver,
Barrel, Sights, Magazine, Stock ...), an AttachmentPoints group, and one group named after
the attachment (Optic_RedDot, Under_Bipod, Mag_Extended ...). Every attachment piece is a
bevelled box or an N-sided cylinder with its vertices baked in the weapon's coordinates.

We cannot upload meshes from here, so each piece is rebuilt as a Roblox Part -- a Block or a
Cylinder -- at the size, place and angle the mesh has. The transform from the GLB into the
weapon template's Handle space is solved from the parts both share (a least-squares
similarity fit, so the importer's scale and turn need not be known), and checked: every
shared part must land within a hair of where the template has it.

Also worked out per attachment: which of the weapon's own parts it replaces (the irons under
an optic, the brake under a suppressor, the stock under a skeleton stock, the magazine under
an extended one). Those are the weapon's pieces missing from that GLB but present in the
others, matched to the template's parts by where they sit.

Writes src/ReplicatedStorage/AttachmentModels.luau.

  lune run tools/attachments/export_weapon.luau -- Carbine_DarkMatter /tmp/dm.json
  python3 tools/attachments/convert.py /tmp/dm.json <dir with the GLBs> [--preview <dir>]

--preview also writes each attachment's rebuilt pieces in the GLB's own space, for
tools/attachments/preview.mjs to draw over the original.
"""
import glob
import json
import math
import os
import re
import struct
import sys

import numpy as np

CT = {5126: "f4", 5123: "u2", 5125: "u4", 5121: "u1"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

# File stem -> (slot, id, display name). The ids are the ones the old catalogue used where an
# old piece had the same job, so anyone who bought it keeps it.
ATTACHMENTS = {
    "Optic_RedDot": ("Sight", "RedDot", "Red Dot"),
    "Optic_Holographic": ("Sight", "Holo", "Holographic"),
    "Optic_Scope4x": ("Sight", "Scope4x", "4x Scope"),
    "Muzzle_Compensator": ("Muzzle", "Compensator", "Compensator"),
    "Muzzle_Suppressor": ("Muzzle", "Suppressor", "Suppressor"),
    "Under_VerticalGrip": ("Underbarrel", "Foregrip", "Vertical Grip"),
    "Under_AngledGrip": ("Underbarrel", "Angled", "Angled Grip"),
    "Under_Bipod": ("Underbarrel", "Bipod", "Bipod"),
    "Side_Laser": ("Side", "Laser", "Laser Sight"),
    "Side_Light": ("Side", "Light", "Flashlight"),
    "Mag_Extended": ("Magazine", "Extended", "Extended Mag"),
    "Stock_Skeleton": ("Stock", "Skeleton", "Skeleton Stock"),
}
ORDER = list(ATTACHMENTS)

# The weapon's decoration, which the imported template lays out a little differently from the
# GLBs (the shards were placed by hand after import). Neither used for the fit nor ever
# replaced by an attachment.
DECORATION = {"DarkMatterCrystals", "DarkMatterEnergy", "VFX", "AttachmentPoints"}
# Decoration that grows on a particular part of the gun, and so leaves when that part is
# hidden. Not the VFX: the flash moves with the muzzle, and the shimmer motes float freely.
GROWN = {"DarkMatterCrystals", "DarkMatterEnergy"}

# See-through pieces: an optic you cannot see through is a blindfold.
LENS = re.compile(r"(Lens|Window)$")


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
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


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
    cache = {}

    def get(i):
        if i not in cache:
            m = local_matrix(nodes[i])
            cache[i] = m if parent[i] is None else get(parent[i]) @ m
        return cache[i]

    return [get(i) for i in range(len(nodes))], parent


class Mesh:
    """One mesh node's triangles in GLB world space."""

    def __init__(self, j, binb, node_index, world):
        node = j["nodes"][node_index]
        self.name = node.get("name", "")
        prim = j["meshes"][node["mesh"]]["primitives"][0]
        self.material = prim.get("material")
        pos = accessor(j, binb, prim["attributes"]["POSITION"])
        pos = (world[:3, :3] @ pos.T).T + world[:3, 3]
        if "indices" in prim:
            idx = accessor(j, binb, prim["indices"]).astype(int).reshape(-1, 3)
        else:
            idx = np.arange(len(pos)).reshape(-1, 3)
        # Weld duplicate positions (split normals) so the topology can be read.
        keys = {}
        remap = np.zeros(len(pos), dtype=int)
        uniq = []
        for i, p in enumerate(pos):
            k = tuple(np.round(p, 6))
            if k not in keys:
                keys[k] = len(uniq)
                uniq.append(p)
            remap[i] = keys[k]
        self.verts = np.array(uniq)
        self.tris = remap[idx]
        lo, hi = self.verts.min(0), self.verts.max(0)
        self.centre = (lo + hi) / 2
        self.aabb = hi - lo

    def cylinder_segments(self):
        """N for an N-sided cylinder with fanned caps, else 0.

        The vertex and triangle counts alone are not enough -- a bevelled box has 96 and 188,
        which is exactly a 47-sided cylinder -- so the caps are checked too: a fanned cap's
        centre is a corner of every one of its N triangles.
        """
        v, t = len(self.verts), len(self.tris)
        n = (v - 2) // 2
        if n < 6 or v != 2 * n + 2 or t != 4 * n:
            return 0
        count = np.sort(np.bincount(self.tris.ravel(), minlength=v))
        return n if count[-1] == n and count[-2] == n else 0

    def fit(self):
        """(kind, centre, axes as columns, size along those axes) in GLB space."""
        n = self.cylinder_segments()
        if n:
            # The two cap centres are the vertices every cap triangle shares.
            count = np.bincount(self.tris.ravel(), minlength=len(self.verts))
            a, b = np.argsort(count)[-2:]
            ca, cb = self.verts[a], self.verts[b]
            axis = cb - ca
            length = np.linalg.norm(axis)
            axis = axis / length
            rel = self.verts - ca
            radial = rel - np.outer(rel @ axis, axis)
            r = np.linalg.norm(radial, axis=1).max()
            r_eff = r * (1 + math.cos(math.pi / n)) / 2
            y = np.cross(axis, [0, 1, 0] if abs(axis[1]) < 0.9 else [1, 0, 0])
            y /= np.linalg.norm(y)
            z = np.cross(axis, y)
            return "Cylinder", (ca + cb) / 2, np.column_stack([axis, y, z]), np.array([length, 2 * r_eff, 2 * r_eff])
        # A (bevelled) box: its axes are the normals of its biggest faces.
        p = self.verts[self.tris]
        cr = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
        area = np.linalg.norm(cr, axis=1)
        keep = area > 1e-14
        normals = cr[keep] / area[keep, None]
        area = area[keep]
        clusters = []
        for nrm, ar in sorted(zip(normals, area), key=lambda x: -x[1]):
            for c in clusters:
                if abs(c[0] @ nrm) > 0.9995:
                    c[1] += ar
                    break
            else:
                clusters.append([nrm, ar])
        clusters.sort(key=lambda c: -c[1])
        d1 = clusters[0][0]
        d2 = None
        for c in clusters[1:]:
            if abs(c[0] @ d1) < 0.02:
                d2 = c[0] - d1 * (c[0] @ d1)
                d2 /= np.linalg.norm(d2)
                break
        if d2 is None:
            w, v = np.linalg.eigh(np.cov((self.verts - self.verts.mean(0)).T))
            d1, d2 = v[:, 2], v[:, 1]
        d3 = np.cross(d1, d2)
        axes = np.column_stack([d1, d2, d3])
        proj = self.verts @ axes
        lo, hi = proj.min(0), proj.max(0)
        centre = axes @ ((lo + hi) / 2)
        return "Block", centre, axes, hi - lo


def umeyama(src, dst):
    """s, R, t minimising |s R src + t - dst|."""
    mu_s, mu_d = src.mean(0), dst.mean(0)
    xs, xd = src - mu_s, dst - mu_d
    cov = xd.T @ xs / len(src)
    u, d, vt = np.linalg.svd(cov)
    s_fix = np.eye(3)
    if np.linalg.det(u) * np.linalg.det(vt) < 0:
        s_fix[2, 2] = -1
    r = u @ s_fix @ vt
    var = (xs ** 2).sum() / len(src)
    s = np.trace(np.diag(d) @ s_fix) / var
    t = mu_d - s * r @ mu_s
    return s, r, t


def srgb(c):
    return [round(float(x), 4) for x in c]


PREVIEW = None


def main():
    global PREVIEW
    args = sys.argv[1:]
    if "--preview" in args:
        k = args.index("--preview")
        PREVIEW = args[k + 1]
        del args[k:k + 2]
    weapon_json, glb_dir = args[0], args[1]
    out_path = args[2] if len(args) > 2 else "src/ReplicatedStorage/AttachmentModels.luau"
    weapon = json.load(open(weapon_json))
    tparts = weapon["parts"]
    by_name = {}
    for p in tparts:
        by_name.setdefault(p["name"], []).append(p)

    files = {}
    for path in glob.glob(os.path.join(glb_dir, "*.glb")):
        stem = re.sub(r"^[0-9a-f]{8}-", "", os.path.basename(path))[:-4]
        if stem in ATTACHMENTS:
            files[stem] = path
    missing = [s for s in ORDER if s not in files]
    if missing:
        sys.exit("missing GLBs: " + ", ".join(missing))

    # Every GLB's own meshes, split into the weapon's and the attachment's.
    loaded = {}
    for stem in ORDER:
        j, binb = load(files[stem])
        world, parent = world_matrices(j)
        nodes = j["nodes"]
        group = next(i for i, n in enumerate(nodes) if n.get("name") == stem and "mesh" not in n)
        att, gun = [], []
        for i, n in enumerate(nodes):
            if "mesh" not in n:
                continue
            anc, inside, skip = parent[i], False, False
            while anc is not None:
                if anc == group:
                    inside = True
                if nodes[anc].get("name") in DECORATION:
                    skip = True
                anc = parent[anc]
            if skip:
                continue
            m = Mesh(j, binb, i, world[i])
            (att if inside else gun).append(m)
        loaded[stem] = (j, att, gun)

    # The transform, from the gun's pieces that the template has under the same (unique) name.
    j0, _, gun0 = loaded[ORDER[0]]
    src, dst, pairs = [], [], []
    seen = {}
    for m in gun0:
        seen[m.name] = seen.get(m.name, 0) + 1
    for m in gun0:
        if seen[m.name] == 1 and len(by_name.get(m.name, [])) == 1:
            t = by_name[m.name][0]
            src.append(m.centre)
            dst.append(t["cf"][:3])
            pairs.append((m, t))
    src, dst = np.array(src), np.array(dst)
    s, R, t = umeyama(src, dst)
    fit = (s * (R @ src.T)).T + t
    err = np.linalg.norm(fit - dst, axis=1)
    print(f"transform from {len(src)} shared parts: scale {s:.4f}, worst {err.max():.4f} studs, rms {math.sqrt((err ** 2).mean()):.4f}")
    if err.max() > 0.02:
        sys.exit("the GLB does not line up with the template; refusing to write")

    def to_handle(p):
        return s * (R @ p) + t

    # Colour and material per GLB material, read off the template's parts that use it.
    looks = {}
    for m, tp in pairs:
        looks.setdefault(m.material, {})
        key = (tp["material"], tuple(round(c, 4) for c in tp["colour"]), round(tp["reflectance"], 3))
        looks[m.material][key] = looks[m.material].get(key, 0) + 1
    look = {k: max(v, key=v.get) for k, v in looks.items()}

    # The weapon's pieces across all the files: a piece missing from one file is replaced by
    # that file's attachment.
    def gun_keys(gun):
        return {(m.name, tuple(np.round(m.centre, 4))) for m in gun}

    union = set()
    for stem in ORDER:
        union |= gun_keys(loaded[stem][2])
    centre_of = {}
    for stem in ORDER:
        for m in loaded[stem][2]:
            centre_of[(m.name, tuple(np.round(m.centre, 4)))] = m.centre

    template_pos = np.array([p["cf"][:3] for p in tparts])

    # Which of the weapon's own parts each piece of decoration (crystal, vein) grows from:
    # the non-decoration part whose box its centre is nearest to -- inside it, in practice.
    solid = [p for p in tparts if p.get("group") not in DECORATION and p["transparency"] < 1]

    def box_distance(pt, p):
        cf = p["cf"]
        rot = np.array(cf[3:]).reshape(3, 3)
        local = rot.T @ (pt - np.array(cf[:3]))
        over = np.maximum(np.abs(local) - np.array(p["size"]) / 2, 0)
        return float(np.linalg.norm(over))

    host_cache = {}

    def host_of(c):
        key = id(c)
        if key not in host_cache:
            at = np.array(c["cf"][:3])
            host_cache[key] = min(solid, key=lambda p: box_distance(at, p))["name"]
        return host_cache[key]
    name_count = {}
    for p in tparts:
        name_count[p["name"]] = name_count.get(p["name"], 0) + 1

    records = []
    for stem in ORDER:
        slot, aid, label = ATTACHMENTS[stem]
        j, att, gun = loaded[stem]
        replaced = set()
        for key in sorted(union - gun_keys(gun)):
            at = to_handle(centre_of[key])
            d = np.linalg.norm(template_pos - at, axis=1)
            k = int(np.argmin(d))
            if d[k] < 0.02:
                replaced.add(k)
        # Hidden by name, so a repeated name is only allowed when every part carrying it is
        # being replaced (the magazine's two MagMid pieces go together).
        hides = []
        for name in sorted({tparts[k]["name"] for k in replaced}):
            every = {k for k, p in enumerate(tparts) if p["name"] == name}
            if not every <= replaced:
                sys.exit(f"{stem}: would hide {name}, but only some of the parts with that name")
            hides.append(name)
        # Decoration that grows ON a hidden part goes with it: the stock's crystals and veins
        # would otherwise hang in the air where the solid stock was, and the standard mag's
        # would stick out through the extended one.
        hidden = set(hides)
        for c in tparts:
            if c.get("group") in GROWN and c["name"] not in hidden:
                h = host_of(c)
                if h in hidden:
                    hides.append(c["name"])
                    hidden.add(c["name"])
        hides.sort()
        parts = []
        preview = []
        for m in att:
            kind, c, axes, size = m.fit()
            preview.append({"name": m.name, "shape": kind, "size": size.tolist(), "centre": c.tolist(),
                            "axes": axes.tolist()})
            pos = to_handle(c)
            rot = R @ axes
            if np.linalg.det(rot) < 0:
                rot[:, 2] *= -1
            mat, colour, refl = look.get(m.material, ("SmoothPlastic", (0.06, 0.06, 0.09), 0))
            part = {
                "name": m.name,
                "shape": kind,
                "size": [round(float(v), 4) for v in size * s],
                "cf": [round(float(v), 5) for v in pos] + [round(float(v), 6) for v in rot.ravel()],
                "colour": srgb(colour),
                "material": mat,
                "reflectance": refl,
            }
            if LENS.search(m.name):
                # Glass the colour of the energy, mostly see-through.
                part["material"] = "Glass"
                part["transparency"] = 0.7
                part["colour"] = [0.55, 0.32, 0.95]
            parts.append(part)
            preview[-1]["colour"] = part["colour"]
            preview[-1]["transparency"] = part.get("transparency", 0)
            preview[-1]["material"] = part["material"]
        # A muzzle device moves the muzzle forward: how far (along the Handle's Z, negative is
        # forward) from the front of the brake it replaces to its own front face. The flash
        # marker and the authored flash petals move by the same amount.
        tip = None
        if slot == "Muzzle":
            def front_of(cf, size):
                c = np.array(cf[:3])
                rot = np.array(cf[3:]).reshape(3, 3)
                return c[2] - np.abs(rot[2]) @ (np.array(size) / 2)
            new_front = min(front_of(pr["cf"], pr["size"]) for pr in parts)
            old_front = min(front_of(tparts[k]["cf"], tparts[k]["size"]) for k in replaced)
            tip = round(float(new_front - old_front), 5)
        records.append((slot, aid, label, stem, parts, hides, tip))
        if PREVIEW:
            os.makedirs(PREVIEW, exist_ok=True)
            json.dump({"glb": os.path.abspath(files[stem]), "group": stem, "parts": preview},
                      open(os.path.join(PREVIEW, stem + ".json"), "w"))
        print(f"{stem:20s} {slot:12s} {aid:12s} {len(parts):3d} parts, hides {len(hides)}")

    write(out_path, weapon["weapon"], records, s, err.max())


def lua_vec(v):
    return ", ".join(f"{x:g}" for x in v)


def write(path, weapon, records, scale, worst):
    lines = [
        "--!strict",
        "-- GENERATED by tools/attachments/convert.py -- do not edit by hand; re-run the converter.",
        "--",
        "-- Attachments modelled for one weapon, from the authored GLBs (the weapon with each",
        "-- attachment fitted). Every piece is a Block or a Cylinder at the size, position and",
        "-- angle its mesh has, in the weapon template's Handle space, so it sits exactly where the",
        "-- artist put it. `hides` are the weapon's own parts the attachment replaces; `shift` (muzzle",
        "-- devices) is how far along the Handle's Z the muzzle moves -- negative is forward.",
        f"-- Fit: GLB -> Handle at scale {scale:.4f}; worst shared-part error {worst:.4f} studs.",
        "",
        "export type Piece = { name: string, shape: string, size: Vector3, cf: CFrame, colour: Color3,",
        "\tmaterial: Enum.Material, reflectance: number, transparency: number }",
        "export type Fitted = { name: string, source: string, parts: { Piece }, hides: { string }, shift: number? }",
        "",
        "local AttachmentModels = {}",
        "",
        "local M = Enum.Material",
        "",
        "local function piece(name: string, shape: string, size: Vector3, cf: CFrame, colour: Color3,",
        "\tmaterial: Enum.Material, reflectance: number, transparency: number?): Piece",
        "\treturn { name = name, shape = shape, size = size, cf = cf, colour = colour, material = material,",
        "\t\treflectance = reflectance, transparency = transparency or 0 }",
        "end",
        "",
        "AttachmentModels.Weapons = {",
        f"\t{weapon} = {{",
    ]
    slots = []
    for rec in records:
        if rec[0] not in slots:
            slots.append(rec[0])
    for slot in slots:
        lines.append(f"\t\t{slot} = {{")
        for (s, aid, label, stem, parts, hides, tip) in records:
            if s != slot:
                continue
            lines.append(f'\t\t\t{aid} = {{ name = "{label}", source = "{stem}.glb",')
            lines.append("\t\t\t\thides = { " + ", ".join(f'"{h}"' for h in hides) + " },")
            if tip is not None:
                lines.append(f"\t\t\t\tshift = {tip:g},")
            lines.append("\t\t\t\tparts = {")
            for p in parts:
                c = p["colour"]
                cf = p["cf"]
                transp = f", {p['transparency']:g}" if p.get("transparency") else ""
                lines.append(
                    f'\t\t\t\t\tpiece("{p["name"]}", "{p["shape"]}", Vector3.new({lua_vec(p["size"])}), '
                    f"CFrame.new({lua_vec(cf)}), Color3.new({lua_vec(c)}), M.{p['material']}, {p['reflectance']:g}{transp}),"
                )
            lines.append("\t\t\t\t},")
            lines.append("\t\t\t},")
        lines.append("\t\t},")
    lines += [
        "\t},",
        "}",
        "",
        "--- The modelled attachment for `weapon` in `slot`, if there is one.",
        "function AttachmentModels.Get(weapon: string, slot: string, id: string): Fitted?",
        "\tlocal w = AttachmentModels.Weapons[weapon]",
        "\tlocal s = w and w[slot]",
        "\treturn s and s[id] or nil",
        "end",
        "",
        "--- Does `weapon` have anything modelled for `slot`?",
        "function AttachmentModels.HasSlot(weapon: string, slot: string): boolean",
        "\tlocal w = AttachmentModels.Weapons[weapon]",
        "\treturn w ~= nil and w[slot] ~= nil and next(w[slot]) ~= nil",
        "end",
        "",
        "return AttachmentModels",
        "",
    ]
    open(path, "w").write("\n".join(lines))
    print("wrote", path)


if __name__ == "__main__":
    main()
