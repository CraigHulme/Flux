--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

function playerMeta:SavePlayer()
	local saveData = {
		steamID = self:SteamID(),
		name = self:Name(),
		joinTime = self.flJoinTime or os.time(),
		lastPlayTime = os.time(),
		data = fl.Serialize(self:GetData())
	}

	hook.Run("SavePlayerData", self, saveData)

	fl.db:EasyWrite("fl_players", {"steamID", self:SteamID()}, saveData)
end

function playerMeta:SetData(data)
	self:SetNetVar("flData", data or {})
end

function playerMeta:SetPlayerData(key, value)
	local data = self:GetData()

	data[key] = value

	self:SetData(data)
end

function playerMeta:GetPlayerData(key, default)
	local data = self:GetData()

	return data[key] or default
end

function playerMeta:SetInitialized(bIsInitialized)
	if (bIsInitialized == nil) then bIsInitialized = true end

	self:SetDTBool(BOOL_INITIALIZED, bIsInitialized)
end

function playerMeta:Notify(message)
	fl.player:Notify(self, message)
end

function playerMeta:GetAmmoTable()
	local ammoTable = {}

	for k, v in pairs(game.GetAmmoList()) do
		local ammoCount = self:GetAmmoCount(k)

		if (ammoCount > 0) then
			ammoTable[k] = ammoCount
		end
	end

	return ammoTable
end

function playerMeta:RestorePlayer()
	fl.db:EasyRead("fl_players", {"steamID", self:SteamID()}, function(result, hasData)
		if (hasData) then
			result = result[1]

			if (result.data) then
				self:SetData(fl.Deserialize(result.data))
			end

			if (result.joinTime) then
				self.flJoinTime = result.joinTime
			end

			if (result.lastPlayTime) then
				self.flLastPlayTime = result.lastPlayTime
			end

			hook.Run("RestorePlayer", self, result)
		else
			ServerLog(self:Name().." has joined for the first time!")

			self:SavePlayer()
		end

		hook.Run("OnPlayerRestored", self)
	end)
end
