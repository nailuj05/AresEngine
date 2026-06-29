-- target.lua
-- Attach this to the target object to verify sendMessage arrives

local Target = {}
Target.__index = Target

Target.fields = {
  { name = "hp", type = "float", default = 100.0 },
}

function Target:onStart()
  Log.print("Target ready, hp = " .. self.hp)
end

function Target:onHit(damage)
  self.hp = self.hp - damage
  Log.print("Target hit for " .. damage .. ", hp now " .. self.hp)
end

return Target
