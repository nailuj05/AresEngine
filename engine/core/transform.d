module engine.core.transform;

import raylib : Matrix, Vector3, Quaternion;
import raylib.raymath;

import engine.core.gameobject;

enum Axis {
  X = 0,
  Y = 1,
  Z = 2,
}

class Transform {
private:
  Vector3    _localPosition = Vector3(0, 0, 0);
  Quaternion _localRotation = Quaternion(0, 0, 0, 1);
  Vector3    _localScale    = Vector3(1, 1, 1);
  Matrix     _localMatrix;
  Matrix     _worldMatrix;
  bool       _localDirty = true;
  bool       _worldDirty = true;

public:
  Transform parent;
  Transform[] children;
  GameObject gameObject;
  
  this(GameObject gameObject) {
    this.gameObject = gameObject;
  }

  // Children

  void addChild(Transform child, bool keepWorldPos = true) nothrow {
    Vector3    wp = child.position;
    Quaternion wr = child.rotation;
    Vector3    ws = child.scale;
    if (child.parent !is null)
      child.parent.removeChild(child, false);
    children     ~= child;
    child.parent  = this;
    // flush this node's world matrix BEFORE the setters walk up to it
    cast(void) worldMatrix();
    markWorldDirty();
    if (keepWorldPos) {
      child.position = wp;
      child.rotation = wr;
      child.scale    = ws;
    }
  }

  void removeChild(Transform child, bool keepWorldPos = true) nothrow {
    import std.algorithm : remove;

    Vector3    wp = child.position;
    Quaternion wr = child.rotation;
    Vector3    ws = child.scale;

    children                = children.remove!(c => c is child);
    child.parent            = null;
    markWorldDirty();

    if (keepWorldPos) {
      child.position = wp;
      child.rotation = wr;
      child.scale    = ws;
    }
  }

  void setParent(Transform newParent, bool keepWorldPos = true) nothrow {
    if (parent is newParent) return;
    if (newParent !is null)
      newParent.addChild(this, keepWorldPos);
    else if (parent !is null)
      parent.removeChild(this, keepWorldPos);
  }
  

  // Transformation

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

  @property Vector3 position() nothrow {
    return worldPosition();
  }
  @property void position(Vector3 worldPos) nothrow {
    if (parent is null) {
      _localPosition = worldPos;
    } else {
      Matrix invParent = MatrixInvert(parent.worldMatrix());
      _localPosition   = Vector3Transform(worldPos, invParent);
    }
    markDirty();
  }
  
  @property Quaternion rotation() nothrow {
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

  @property Vector3 scale() nothrow {
    return worldScale();
  }
  @property void scale(Vector3 ws) nothrow {
    if (parent is null) {
      _localScale = ws;
    } else {
      // Use the inverse parent world matrix to derive local scale correctly,
      // even when the parent carries rotation or shear.
      auto parentScale = parent.scale;
      _localScale = Vector3(ws.x / parentScale.x, ws.y / parentScale.y, ws.z / parentScale.z,);
    }
    markDirty();
  }

  @property Vector3 forward() nothrow {
    return Vector3Normalize(Vector3RotateByQuaternion(Vector3(0, 0, 1), rotation));
  }

  @property Vector3 up() nothrow {
    return Vector3Normalize(Vector3RotateByQuaternion(Vector3(0, 1, 0), rotation));
  }

  @property Vector3 right() nothrow {
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

  // local <-> world point conversion (includes translation)
  Vector3 transformPoint(Vector3 localPoint) nothrow {
    return Vector3Transform(localPoint, worldMatrix());
  }
  Vector3 inverseTransformPoint(Vector3 worldPoint) nothrow {
    return Vector3Transform(worldPoint, MatrixInvert(worldMatrix()));
  }

  // direction conversion: rotation only, no translation or scale
  Vector3 transformDirection(Vector3 localDir) nothrow {
    return Vector3RotateByQuaternion(localDir, rotation());
  }
  Vector3 inverseTransformDirection(Vector3 worldDir) nothrow {
    return Vector3RotateByQuaternion(worldDir, QuaternionInvert(rotation()));
  }

  @property Matrix worldToLocalMatrix() nothrow {
    return MatrixInvert(worldMatrix());
  }


package:
  void markDirty() nothrow {
    _localDirty = true;
    markWorldDirty();
  }

  // Mark only the world matrix dirty and propagate to children.
  void markWorldDirty() nothrow {
    if (_worldDirty)
      return;

    _worldDirty = true;

    foreach (child; children) {
      child.markWorldDirty();
    }
  }

private:
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

  Vector3 worldPosition() nothrow {
    Matrix wm = worldMatrix();
    return Vector3(wm.m12, wm.m13, wm.m14);
  }

  Vector3 worldScale() nothrow {
    Matrix wm = worldMatrix();
    // Each basis column's length is the corresponding world scale axis.
    float sx = Vector3Length(Vector3(wm.m0, wm.m1, wm.m2));
    float sy = Vector3Length(Vector3(wm.m4, wm.m5, wm.m6));
    float sz = Vector3Length(Vector3(wm.m8, wm.m9, wm.m10));
    return Vector3(sx, sy, sz);
  }

  Quaternion worldRotation() nothrow {
    Matrix wm = worldMatrix();
    // Strip scale so we hand a pure rotation matrix to QuaternionFromMatrix.
    float sx = Vector3Length(Vector3(wm.m0, wm.m1, wm.m2));
    float sy = Vector3Length(Vector3(wm.m4, wm.m5, wm.m6));
    float sz = Vector3Length(Vector3(wm.m8, wm.m9, wm.m10));
    Matrix rot = wm;
    rot.m0  /= sx; rot.m1  /= sx; rot.m2  /= sx;
    rot.m4  /= sy; rot.m5  /= sy; rot.m6  /= sy;
    rot.m8  /= sz; rot.m9  /= sz; rot.m10 /= sz;
    // Zero out translation so only the 3x3 rotation block remains.
    rot.m12 = 0; rot.m13 = 0; rot.m14 = 0;
    return QuaternionFromMatrix(rot);
  }
}
