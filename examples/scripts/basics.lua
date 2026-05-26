local Player = {}
Player.__index = Player

-- config
Player.fields = {
    { name = "speed",     type = "float",  default = 5.0      },
    { name = "health",    type = "int",    default = 100      },
    { name = "canJump",   type = "bool",   default = true     },
    { name = "label",     type = "string", default = "player" },
    { name = "amplitude", type = "float",  default = 1.5      },
}

function Player:onStart()
   self.yaw      = 0.0
   self.pitch    = 0.0
   self.scaleVal = 1.0

   local x, y, z = Transform.getPosition(self.gameObject)
   Log.print(string.format("Player started at (%.2f, %.2f, %.2f)", x, y, z))
   Log.print("Controls: WASD move, SHIFT sprint, mouse look, scroll scale")
   Log.print("  LMB: log position  RMB: reset  F1: dump transform  ESC: log msg")
end

function Player:onUpdate(dt)
   -- movement (WASD + shift sprint)
   local spd = Input.isKeyDown(Input.Key.LEFT_SHIFT) and self.speed * 2 or self.speed
   local dx, dz = 0.0, 0.0
   if Input.isKeyDown(Input.Key.W) then dz = dz - spd * dt end
   if Input.isKeyDown(Input.Key.S) then dz = dz + spd * dt end
   if Input.isKeyDown(Input.Key.A) then dx = dx - spd * dt end
   if Input.isKeyDown(Input.Key.D) then dx = dx + spd * dt end
   if dx ~= 0.0 or dz ~= 0.0 then
      Transform.translate(self.gameObject, dx, 0, dz)
   end

   -- vertical (Q/E)
   if Input.isKeyDown(Input.Key.E) then Transform.translate(self.gameObject, 0,  spd * dt, 0) end
   if Input.isKeyDown(Input.Key.Q) then Transform.translate(self.gameObject, 0, -spd * dt, 0) end

   -- RMB: reset transform
   if Input.isMouseButtonPressed(Input.Mouse.RIGHT) then
      Transform.setPosition(self.gameObject, 0, 0, 0)
      Transform.setRotation(self.gameObject, 0, 0, 0)
      Transform.setScale(self.gameObject, 1, 1, 1)
      self.yaw, self.pitch, self.scaleVal = 0.0, 0.0, 1.0
      Log.print("transform reset")
   end

   -- F1: dump full transform state
   if Input.isKeyPressed(Input.Key.F1) then
      local x,  y,  z  = Transform.getPosition(self.gameObject)
      local rx, ry, rz = Transform.getRotation(self.gameObject)
      local sx, sy, sz = Transform.getScale(self.gameObject)
      Log.print("=== Transform dump ===")
      Log.print(string.format("  pos:   (%.3f, %.3f, %.3f)", x,  y,  z))
      Log.print(string.format("  rot:   (%.3f, %.3f, %.3f)", rx, ry, rz))
      Log.print(string.format("  scale: (%.3f, %.3f, %.3f)", sx, sy, sz))
   end
end

function Player:onDestroy()
   local x, y, z = Transform.getPosition(self.gameObject)
   Log.print(string.format("Player destroyed at (%.2f, %.2f, %.2f)", x, y, z))
end

return Player
