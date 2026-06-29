-- test_messaging.lua
-- Tests: object references, prefab instantiation, sendMessage

local Test = {}
Test.__index = Test

Test.fields = {
  { name = "target",    type = "object" },
  { name = "spawnPoint", type = "object" },
  { name = "enemyPrefab", type = "object" },
  { name = "hitDamage", type = "float", default = 10.0 },
}

function Test:onStart()
  Log.print("onStart: target = " .. tostring(self.target))
  Log.print("onStart: enemyPrefab = " .. tostring(self.enemyPrefab))

  -- test scene object reference
  if self.target then
    local x, y, z = Transform.getPosition(self.target)
    Log.print("target position: " .. x .. ", " .. y .. ", " .. z)
  else
    Log.print("WARNING: target not assigned or not found in scene")
  end

  -- test prefab instantiation
  if self.enemyPrefab then
    local inst = Prefab.instantiate(self.enemyPrefab)
    if inst then
      Log.print("prefab instantiated OK")
      -- move it to the spawnPoint if set
      if self.spawnPoint then
        local sx, sy, sz = Transform.getPosition(self.spawnPoint)
        Transform.setPosition(inst, sx, sy, sz)
        Log.print("moved instance to spawnPoint: " .. sx .. ", " .. sy .. ", " .. sz)
      end
    else
      Log.print("WARNING: prefab instantiation failed (bad path?)")
    end
  end
end

function Test:onUpdate(dt)
  -- press Space to send a message to target
  if Input.isKeyPressed(Input.Key.SPACE) then
    if self.target then
      Log.print("sending onHit to target")
      GameObject.sendMessage(self.target, "onHit", self.hitDamage)
    else
      Log.print("no target to send message to")
    end
  end
end

return Test
