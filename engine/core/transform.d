module engine.core.transform;

import raylib : Matrix, Vector3, Quaternion;
import raylib.raymath;

enum Axis {
  X = 0,
  Y = 1,
  Z = 2,
}

struct Transform {
private:
  Vector3    _localPosition = Vector3(0, 0, 0);
  Quaternion _localRotation = Quaternion(0, 0, 0, 1);
  Vector3    _localScale    = Vector3(1, 1, 1);
  Matrix     _localMatrix;
  Matrix     _worldMatrix;
  bool       _localDirty = true;
  bool       _worldDirty = true;

  // Children list for dirty propagation
  Transform*[] _children;

public:
  Transform* parent = null;

  @property const(Vector3) localPosition() const nothrow {
    return _localPosition;
  }
  @property void localPosition(Vector3 value) nothrow {
    _localPosition = value;
    markDirty();
  }

  @property const(Quaternion) localRotation() const nothrow {
    return _localRotation;
  }
  @property void localRotation(Quaternion value) nothrow {
    _localRotation = value;
    markDirty();
  }

  @property const(Vector3) localScale() const nothrow {
    return _localScale;
  }
  @property void localScale(Vector3 value) nothrow {
    _localScale = value;
    markDirty();
  }

  @property const(Vector3) position() const nothrow {
    return worldPosition();
  }
  @property void position(Vector3 worldPos) nothrow {
    if (parent is null) {
      _localPosition = worldPos;
    } else {
      // Bring worldPos into local space via the inverse of the parent's world matrix
      Matrix invParent = MatrixInvert((cast(Transform*) parent).worldMatrix());
      _localPosition   = Vector3Transform(worldPos, invParent);
    }
    markDirty();
  }
  
  @property const(Quaternion) rotation() const nothrow {
    return worldRotation();
  }
  @property void rotation(Quaternion worldRot) nothrow {
    if (parent is null) {
      _localRotation = worldRot;
    } else {
      Quaternion parentInv = QuaternionInvert(parent.rotation);
      _localRotation       = QuaternionMultiply(parentInv, worldRot);
    }
    markDirty();
  }

  @property const(Vector3) scale() const nothrow {
    return worldScale();
  }
  @property void scale(Vector3 ws) nothrow {
    if (parent is null) {
      _localScale = ws;
    } else {
      // Use the inverse parent world matrix to derive local scale correctly,
      // even when the parent carries rotation or shear.
      auto parentScale = parent.scale;
      _localScale = Vector3(
                            ws.x / parentScale.x,
                            ws.y / parentScale.y,
                            ws.z / parentScale.z,
                            );
    }
    markDirty();
  }

  @property Vector3 forward() const nothrow {
    return Vector3Normalize(Vector3RotateByQuaternion(Vector3(0, 0, 1), rotation));
  }

  @property Vector3 up() const nothrow {
    return Vector3Normalize(Vector3RotateByQuaternion(Vector3(0, 1, 0), rotation));
  }

  @property Vector3 right() const nothrow {
    return Vector3Normalize(Vector3RotateByQuaternion(Vector3(1, 0, 0), rotation));
  }

  
  Matrix localMatrix() nothrow {
    updateLocalMatrix();
    return _localMatrix;
  }

  Matrix worldMatrix() nothrow {
    updateWorldMatrix();
    return _worldMatrix;
  }

  // Attach a child and set its parent pointer.
  void addChild(Transform* child) nothrow {
    assert(child !is null);
    child.parent = &this;
    _children   ~= child;
    child.markDirty();
  }

  // Detach a child and clear its parent pointer.
  void removeChild(Transform* child) nothrow {
    import std.algorithm : remove;
    _children  = _children.remove!(c => c is child);
    child.parent = null;
    child.markDirty();
  }

private:

  void markDirty() nothrow {
    _localDirty = true;
    markWorldDirty();
  }

  // Mark only the world matrix dirty and propagate to children.
  void markWorldDirty() nothrow {
    _worldDirty = true;
    foreach (child; _children)
      child.markWorldDirty();
  }

  void updateLocalMatrix() nothrow {
    if (!_localDirty)
      return;

    Matrix translation = MatrixTranslate(_localPosition.x, _localPosition.y, _localPosition.z);
    Matrix rotationMat = QuaternionToMatrix(_localRotation);
    Matrix scaleMat    = MatrixScale(_localScale.x, _localScale.y, _localScale.z);

    // Correct TRS order: scale -> rotate -> translate
    _localMatrix = MatrixMultiply(MatrixMultiply(scaleMat, rotationMat), translation);
    _localDirty  = false;
  }

  void updateWorldMatrix() nothrow {
    if (!_worldDirty)
      return;

    updateLocalMatrix();

    if (parent is null) {
      _worldMatrix = _localMatrix;
    } else {
      _worldMatrix = MatrixMultiply(parent.worldMatrix(), _localMatrix);
    }

    _worldDirty = false;
  }

  Vector3 worldPosition() const nothrow {
    if (parent is null)
      return _localPosition;
    auto parentPos = parent.position;
    return Vector3(
      parentPos.x + _localPosition.x,
      parentPos.y + _localPosition.y,
      parentPos.z + _localPosition.z,
    );
  }

  Quaternion worldRotation() const nothrow {
    if (parent is null)
      return _localRotation;
    return QuaternionMultiply(parent.rotation, _localRotation);
  }

  Vector3 worldScale() const nothrow {
    if (parent is null)
      return _localScale;
    auto ps = parent.scale;
    return Vector3(
      ps.x * _localScale.x,
      ps.y * _localScale.y,
      ps.z * _localScale.z,
    );
  }
}
