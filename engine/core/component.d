module engine.core.component;

import std.meta   : AliasSeq;

import engine.core.gameobject;

// known components, needed for serialization and add component
import engine.rendering.modelrenderer: ModelRenderer;
import engine.scripting.luascript : LuaScript;
import engine.rendering.camera : Camera;
import engine.oscillator : Oscillator;
import engine.physics.rigidbody : Rigidbody;
import engine.physics.boxcollider : BoxCollider;
import engine.physics.spherecollider : SphereCollider;

alias KnownComponents = AliasSeq!(BoxCollider, Camera, LuaScript, ModelRenderer, Oscillator, Rigidbody, SphereCollider);

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
    abstract float drawInspector(float offsetX, float offsetY, float panelW);
  }
}
