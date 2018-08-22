--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]local COMMAND = Command("fall")
COMMAND.Name = "Fall"
COMMAND.Description = "Fall down on the ground."
COMMAND.Syntax = "[number GetUpTime]"
COMMAND.Category = "roleplay"
COMMAND.Aliases = {"fallover", "charfallover"}
COMMAND.noConsole = true

function COMMAND:OnRun(player, delay)
  if (isnumber(delay) and delay > 0) then
    delay = math.Clamp(delay or 0, 2, 60)
  end

  if (player:Alive() and !player:IsRagdolled()) then
    player:SetRagdollState(RAGDOLL_FALLENOVER)

    if (delay and delay > 0) then
      player:RunCommand("getup "..tostring(delay))
    end
  else
    player:Notify("You cannot do this right now!")
  end
end

COMMAND:Register()
