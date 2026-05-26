local Player = {}
Player.__index = Player

-- config
local SPEED       = 5.0
local SPRINT_MULT = 2.5
local MOUSE_SENS  = 0.15
local SCALE_SPEED = 0.1
local SCALE_MIN   = 0.5
local SCALE_MAX   = 3.0

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
   local spd = Input.isKeyDown(Input.Key.LEFT_SHIFT) and SPEED * SPRINT_MULT or SPEED
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

   -- mouse look
   local mx, my = Input.getMouseDelta()
   if mx ~= 0.0 or my ~= 0.0 then
      self.yaw   = self.yaw   + mx * MOUSE_SENS
      self.pitch = math.max(-89.0, math.min(89.0, self.pitch + my * MOUSE_SENS))
      Transform.setRotation(self.gameObject, self.pitch, self.yaw, 0)
   end

   -- scroll: uniform scale
   local wheel = Input.getMouseWheelMove()
   if wheel ~= 0.0 then
      self.scaleVal = math.max(SCALE_MIN, math.min(SCALE_MAX, self.scaleVal + wheel * SCALE_SPEED))
      Transform.setScale(self.gameObject, self.scaleVal, self.scaleVal, self.scaleVal)
      Log.print(string.format("scale: %.2f", self.scaleVal))
   end

   -- LMB: log current position
   if Input.isMouseButtonPressed(Input.Mouse.LEFT) then
      local x, y, z = Transform.getPosition(self.gameObject)
      Log.print(string.format("pos: (%.2f, %.2f, %.2f)", x, y, z))
   end

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

   -- F2: snap to a fixed position (tests setPosition)
   if Input.isKeyPressed(Input.Key.F2) then
      Transform.setPosition(self.gameObject, 5, 2, -3)
      Log.print("snapped to (5, 2, -3)")
   end

   -- ESC
   if Input.isKeyPressed(Input.Key.ESCAPE) then
      Log.print("ESC pressed")
   end
end

function Player:onDestroy()
   local x, y, z = Transform.getPosition(self.gameObject)
   Log.print(string.format("Player destroyed at (%.2f, %.2f, %.2f)", x, y, z))
end

return Player
