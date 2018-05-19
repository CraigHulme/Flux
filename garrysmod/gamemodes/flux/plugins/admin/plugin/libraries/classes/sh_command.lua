--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

class "CCommand"

CCommand.id = "undefined"
CCommand.Name = "Unknown"
CCommand.Description = "An undescribed command."
CCommand.Syntax = "[none]"
CCommand.Immunity = false
CCommand.PlayerArg = nil
CCommand.Arguments = 0
CCommand.noConsole = false

function CCommand:CCommand(id)
  self.id = id
end

function CCommand:OnRun() end

function CCommand:__tostring()
  return "Command ["..self.id.."]["..self.Name.."]"
end

function CCommand:Register()
  fl.command:Create(self.id, self)
end

Command = CCommand
