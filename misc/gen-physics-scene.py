import argparse
import json
from typing import List, Tuple, Union

def create_cube(x: float, y: float, z: float, name: str, color: Tuple[int, int, int] = (255, 0, 0)) -> dict:
    """Create a cube entity with MeshRenderer, BoxCollider, and Rigidbody."""
    return {
        "active": True,
        "children": [],
        "components": [
            {
                "enabled": True,
                "fields": {
                    "color": {"a": 255, "b": color[2], "g": color[1], "r": color[0]},
                    "meshPath": ""
                },
                "type": "MeshRenderer"
            },
            {
                "enabled": True,
                "fields": {},
                "type": "BoxCollider"
            },
            {
                "enabled": True,
                "fields": {
                    "angularDrag": 0.0500000007450580597,
                    "drag": 0.00999999977648258209,
                    "isKinematic": False,
                    "mass": 1.0,
                    "restitution": 0.300000011920928955,
                    "useGravity": True
                },
                "type": "Rigidbody"
            }
        ],
        "name": name,
        "position": {"x": x, "y": y, "z": z},
        "rotation": {"w": 1.0, "x": 0.0, "y": 0.0, "z": 0.0},
        "scale": {"x": 1.0, "y": 1.0, "z": 1.0}
    }

def generate_grid(nx: int, ny: int, nz: int,
                  spacing: Tuple[float, float, float],
                  origin: Tuple[float, float, float],
                  base_name: str = "Cube") -> List[dict]:
    """Generate a 3D grid of cubes."""
    cubes = []
    dx, dy, dz = spacing
    ox, oy, oz = origin
    for i in range(nx):
        for j in range(ny):
            for k in range(nz):
                x = ox + i * dx
                y = oy + j * dy
                z = oz + k * dz
                name = f"{base_name}_{i}_{j}_{k}"
                cubes.append(create_cube(x, y, z, name))
    return cubes

def main():
    parser = argparse.ArgumentParser(description="Generate a scene with a grid of cubes.")
    parser.add_argument("--nx", type=int, default=3, help="Number of cubes along X axis")
    parser.add_argument("--ny", type=int, default=2, help="Number of cubes along Y axis")
    parser.add_argument("--nz", type=int, default=3, help="Number of cubes along Z axis")
    parser.add_argument("--spacing", type=float, nargs="+", default=[1.5, 1.5, 1.5],
                        help="Spacing between cubes (dx dy dz) or a single value")
    parser.add_argument("--origin", type=float, nargs="+", default=[0.0, 1.0, 0.0],
                        help="Origin position of the grid (x y z)")
    parser.add_argument("--output", type=str, default="scene.json", help="Output JSON file")
    args = parser.parse_args()

    # Handle spacing: if single value, replicate to three axes
    if len(args.spacing) == 1:
        spacing = (args.spacing[0], args.spacing[0], args.spacing[0])
    elif len(args.spacing) == 3:
        spacing = tuple(args.spacing)
    else:
        raise ValueError("--spacing must have 1 or 3 values")

    # Handle origin
    if len(args.origin) == 3:
        origin = tuple(args.origin)
    else:
        raise ValueError("--origin must have 3 values")

    # Generate cubes
    cubes = generate_grid(args.nx, args.ny, args.nz, spacing, origin, base_name="Cube")

    # Build the full scene (floor + cubes + camera)
    floor = {
        "active": True,
        "children": [],
        "components": [
            {
                "enabled": True,
                "fields": {
                    "color": {"a": 255, "b": 83, "g": 83, "r": 107},
                    "meshPath": ""
                },
                "type": "MeshRenderer"
            },
            {
                "enabled": True,
                "fields": {},
                "type": "BoxCollider"
            }
        ],
        "name": "Floor",
        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
        "rotation": {"w": 1.0, "x": 0.0, "y": 0.0, "z": 0.0},
        "scale": {"x": 25.0, "y": 0.1, "z": 25.0}
    }

    camera = {
        "active": True,
        "children": [],
        "components": [
            {
                "enabled": True,
                "fields": {
                    "farPlane": 1000.0,
                    "fieldOfView": 90.0,
                    "nearPlane": 0.1,
                    "projection": 0
                },
                "type": "Camera"
            }
        ],
        "name": "Camera",
        "position": {"x": 0.0, "y": 15.0, "z": -20.0},
        "rotation": {"w": 0.975952804088592529, "x": 0.217981964349746704, "y": 0.0, "z": 0.0},
        "scale": {"x": 1.0, "y": 1.0, "z": 1.0}
    }

    scene = {
        "name": "main",
        "roots": [floor] + [camera] + cubes
    }

    with open(args.output, "w") as f:
        json.dump(scene, f, indent=4)

    print(f"Scene written to {args.output} with {len(cubes)} cubes.")

if __name__ == "__main__":
    main()
