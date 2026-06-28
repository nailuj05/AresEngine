module engine.asset;

// UDA for inspector choosing
enum AssetKind { Model, Material, Shader, Object }
struct Asset { AssetKind kind; }
