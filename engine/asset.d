module engine.asset;

// UDA for inspector choosing
enum AssetKind { Model /*, Material, Shader*/ }
struct Asset { AssetKind kind; }
