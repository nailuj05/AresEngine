module engine.core.component;

import std.meta   : AliasSeq;

import engine.core.gameobject;

// known components, needed for serialization and add component
import engine.rendering.meshrenderer: MeshRenderer;
import engine.scripting.luascript : LuaScript;
import engine.rendering.camera : Camera;
import engine.oscillator : Oscillator;
import engine.physics.collider : BoxCollider, CapsuleCollider, SphereCollider;
import engine.physics.rigidbody : Rigidbody;

//alias KnownComponents = AliasSeq!(BoxCollider, Camera, CapsuleCollider, LuaScript, MeshRenderer, Oscillator, Rigidbody, SphereCollider);
alias KnownComponents = AliasSeq!(Camera, LuaScript, MeshRenderer, Oscillator);

// @DontSerialize Field
struct DontSerialize {}

mixin template Named(string s)
{
  enum string typeName = s; // for serialization
  override @property string name() const
  {
    return s;
  }
}

abstract class Component {
  GameObject owner;
  bool enabled = true;
  @property string name() const;

  void onEditorStart()    {}
  void onStart()          {}
  void onUpdate(float dt) {}
  void onDraw()           {}
  void onDestroy()        {}
  void onEditorDestroy()  {}

  version(Editor) {
    abstract ulong drawInspector(ulong offsetX, ulong offsetY, ulong panelW);
  }
}
