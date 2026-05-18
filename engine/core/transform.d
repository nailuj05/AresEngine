module engine.core.transform;

import raylib : Vector3, Quaternion;

struct Transform {
    Vector3    position = Vector3(0, 0, 0);
    Quaternion rotation = Quaternion(0, 0, 0, 1); // identity
    Vector3    scale    = Vector3(1, 1, 1);
    Transform* parent;
    Transform*[] children;
}
