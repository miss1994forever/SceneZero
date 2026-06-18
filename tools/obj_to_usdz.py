#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def parse_mtl(path):
    materials = {}
    current = None
    if not path.exists():
        return materials

    for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        parts = raw_line.strip().split()
        if not parts:
            continue
        if parts[0] == "newmtl" and len(parts) > 1:
            current = parts[1]
            materials[current] = (0.78, 0.78, 0.78)
        elif parts[0] == "Kd" and current and len(parts) >= 4:
            materials[current] = tuple(float(value) for value in parts[1:4])

    return materials


def parse_obj(path):
    points = []
    faces_by_material = {}
    current_material = "default"
    mtl_name = None

    for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if parts[0] == "mtllib" and len(parts) > 1:
            mtl_name = " ".join(parts[1:])
        elif parts[0] == "usemtl" and len(parts) > 1:
            current_material = parts[1]
        elif parts[0] == "v" and len(parts) >= 4:
            points.append(tuple(float(value) for value in parts[1:4]))
        elif parts[0] == "f" and len(parts) >= 4:
            face = []
            for token in parts[1:]:
                index_text = token.split("/")[0]
                index = int(index_text)
                if index < 0:
                    index = len(points) + index
                else:
                    index -= 1
                face.append(index)
            faces_by_material.setdefault(current_material, []).append(face)

    return points, faces_by_material, mtl_name


def usd_identifier(name):
    cleaned = "".join(char if char.isalnum() else "_" for char in name)
    if not cleaned or cleaned[0].isdigit():
        cleaned = f"_{cleaned}"
    return cleaned


def fmt_float(value):
    return f"{value:.6g}"


def write_usda(obj_path, usda_path, root_name):
    points, faces_by_material, mtl_name = parse_obj(obj_path)
    material_path = obj_path.with_name(mtl_name) if mtl_name else obj_path.with_suffix(".mtl")
    materials = parse_mtl(material_path)

    if not points or not faces_by_material:
        raise ValueError(f"No mesh data found in {obj_path}")

    all_material_names = sorted(faces_by_material.keys())
    lines = [
        "#usda 1.0",
        "(",
        '    defaultPrim = "Root"',
        "    metersPerUnit = 1",
        "    upAxis = \"Y\"",
        ")",
        "",
        'def Xform "Root"',
        "{",
        '    def Scope "Materials"',
        "    {",
    ]

    for material_name in all_material_names:
        color = materials.get(material_name, (0.78, 0.78, 0.78))
        mat_id = usd_identifier(material_name)
        lines.extend([
            f'        def Material "{mat_id}"',
            "        {",
            '            token outputs:surface.connect = </Root/Materials/{}/PreviewSurface.outputs:surface>'.format(mat_id),
            f'            def Shader "PreviewSurface"',
            "            {",
            '                uniform token info:id = "UsdPreviewSurface"',
            f"                color3f inputs:diffuseColor = ({fmt_float(color[0])}, {fmt_float(color[1])}, {fmt_float(color[2])})",
            "                float inputs:roughness = 0.62",
            "                token outputs:surface",
            "            }",
            "        }",
        ])

    lines.extend([
        "    }",
        "",
    ])

    for material_name in all_material_names:
        faces = faces_by_material[material_name]
        mesh_id = usd_identifier(f"{root_name}_{material_name}")
        mat_id = usd_identifier(material_name)
        counts = [len(face) for face in faces]
        indices = [index for face in faces for index in face]

        point_text = ", ".join(
            f"({fmt_float(x)}, {fmt_float(y)}, {fmt_float(z)})"
            for x, y, z in points
        )
        count_text = ", ".join(str(count) for count in counts)
        index_text = ", ".join(str(index) for index in indices)

        lines.extend([
            f'    def Mesh "{mesh_id}"',
            "    {",
            f"        point3f[] points = [{point_text}]",
            f"        int[] faceVertexCounts = [{count_text}]",
            f"        int[] faceVertexIndices = [{index_text}]",
            '        uniform token subdivisionScheme = "none"',
            f"        rel material:binding = </Root/Materials/{mat_id}>",
            "    }",
            "",
        ])

    lines.append("}")
    usda_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def package_usdz(usda_path, usdz_path):
    usdz_path = usdz_path.resolve()
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        staged_usda = temp_path / usda_path.name
        shutil.copy2(usda_path, staged_usda)
        if usdz_path.exists():
            usdz_path.unlink()
        subprocess.run(
            ["zip", "-0", str(usdz_path), staged_usda.name],
            cwd=temp_path,
            check=True,
            stdout=subprocess.DEVNULL,
        )


def main():
    parser = argparse.ArgumentParser(description="Convert a simple OBJ mesh to a USDZ package.")
    parser.add_argument("obj", type=Path)
    parser.add_argument("usdz", type=Path)
    parser.add_argument("--name", default=None)
    args = parser.parse_args()

    root_name = args.name or args.obj.stem
    with tempfile.TemporaryDirectory() as temp_dir:
        usda_path = Path(temp_dir) / f"{root_name}.usda"
        write_usda(args.obj, usda_path, root_name)
        args.usdz.parent.mkdir(parents=True, exist_ok=True)
        package_usdz(usda_path, args.usdz)


if __name__ == "__main__":
    main()
