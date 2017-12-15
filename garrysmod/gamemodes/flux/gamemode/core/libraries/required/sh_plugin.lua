--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (plugin) then return end

library.New "plugin"

local stored = {}
local unloaded = {}
local hooksCache = {}
local reloadData = {}
local loadCache = {}
local defaultExtras = {
	"libraries",
	"libraries/meta",
	"libraries/classes",
	"libs",
	"libs/meta",
	"libs/classes",
	"classes",
	"meta",
	"config",
	"languages",
	"ui/controllers",
	"ui/view",
	"tools",
	"themes",
	"entities"
}

local extras = table.Copy(defaultExtras)

function plugin.GetAll()
	return stored
end

function plugin.GetCache()
	return hooksCache
end

function plugin.ClearCache()
	plugin.ClearExtras()

	hooksCache = {}
	loadCache = {}
end

function plugin.ClearLoadCache()
	loadCache = {}
end

function plugin.ClearExtras()
	extras = table.Copy(defaultExtras)
end

class "CPlugin"

function CPlugin:CPlugin(id, data)
	self.m_Name = data.name or "Unknown Plugin"
	self.m_Author = data.author or "Unknown Author"
	self.m_Folder = data.folder or name:gsub(" ", "_"):lower()
	self.m_Description = data.description or "This plugin has no description."
	self.m_UniqueID = id or data.id or name:MakeID() or "unknown"

	table.Merge(self, data)
end

function CPlugin:GetName()
	return self.m_Name
end

function CPlugin:GetFolder()
	return self.m_Folder
end

function CPlugin:GetAuthor()
	return self.m_Author
end

function CPlugin:GetDescription()
	return self.m_Description
end

function CPlugin:SetName(name)
	self.m_Name = name or self.m_Name or "Unknown Plugin"
end

function CPlugin:SetAuthor(author)
	self.m_Author = author or self.m_Author or "Unknown"
end

function CPlugin:SetDescription(desc)
	self.m_Description = desc or self.m_Description or "No description provided!"
end

function CPlugin:SetData(data)
	table.Merge(self, data)
end

function CPlugin:SetAlias(alias)
	if (isstring(alias)) then
		_G[alias] = self
		self.alias = alias
	end
end

function CPlugin:__tostring()
	return "Plugin ["..self.m_Name.."]"
end

function CPlugin:Register()
	plugin.Register(self)
end

Plugin = CPlugin

function plugin.CacheFunctions(obj, id)
	for k, v in pairs(obj) do
		if (isfunction(v)) then
			hooksCache[k] = hooksCache[k] or {}
			table.insert(hooksCache[k], {v, obj, id = id})
		end
	end
end

function plugin.AddHooks(id, obj)
	plugin.CacheFunctions(obj, id)
end

function plugin.RemoveHooks(id)
	for k, v in pairs(hooksCache) do
		for k2, v2 in ipairs(v) do
			if (v2.id and v2.id == id) then
				hooksCache[k][k2] = nil
			end
		end
	end
end

function plugin.Find(id)
	if (stored[id]) then
		return stored[id], id
	else
		for k, v in pairs(stored) do
			if (v.m_UniqueID == id or v:GetFolder() == id or v:GetName() == id) then
				return v, k
			end
		end
	end
end

-- A function to unhook a plugin from cache.
function plugin.RemoveFromCache(id)
	local pluginTable = plugin.Find(id) or (istable(id) and id)

	-- Awful lot of if's and end's.
	if (pluginTable) then
		if (pluginTable.OnUnhook) then
			try {
				pluginTable.OnUnhook, pluginTable
			} catch {
				function(exception)
					ErrorNoHalt("[Flux:Plugin] OnUnhook method has failed to run! "..tostring(pluginTable).."\n"..tostring(exception).."\n")
				end
			}
		end

		for k, v in pairs(pluginTable) do
			if (isfunction(v) and hooksCache[k]) then
				for index, tab in ipairs(hooksCache[k]) do
					if (tab[2] == pluginTable) then
						table.remove(hooksCache[k], index)

						break
					end
				end
			end
		end
	end
end

-- A function to cache existing plugin's hooks.
function plugin.ReCache(id)
	local pluginTable = plugin.Find(id)

	if (pluginTable) then
		if (pluginTable.OnRecache) then
			try {
				pluginTable.OnRecache, pluginTable
			} catch {
				function(exception)
					ErrorNoHalt("[Flux:Plugin] OnRecache method has failed to run! "..tostring(pluginTable).."\n"..tostring(exception).."\n")
				end
			}
		end

		plugin.CacheFunctions(pluginTable)
	end
end

-- A function to remove the plugin entirely.
function plugin.Remove(id)
	local pluginTable, pluginID = plugin.Find(id)

	if (pluginTable) then
		if (pluginTable.OnRemoved) then
			try {
				pluginTable.OnRemoved, pluginTable
			} catch {
				function(exception)
					ErrorNoHalt("[Flux:Plugin] OnRemoved method has failed to run! "..tostring(pluginTable).."\n"..tostring(exception).."\n")
				end
			}
		end

		plugin.RemoveFromCache(id)

		stored[pluginID] = nil
	end
end

function plugin.IsDisabled(folder)
	if (fl.sharedTable.disabledPlugins) then
		return fl.sharedTable.disabledPlugins[folder]
	end
end

function plugin.HasLoaded(obj)
	if (istable(obj)) then
		return loadCache[obj.m_UniqueID]
	elseif (isstring(obj)) then
		return loadCache[obj]
	end

	return false
end

function plugin.Register(obj)
	plugin.CacheFunctions(obj)

	if (obj.ShouldRefresh == false) then
		reloadData[obj:GetFolder()] = false
	else
		reloadData[obj:GetFolder()] = true
	end

	if (SERVER) then
		if (Schema == obj) then
			local folderName = obj.folder:RemoveTextFromEnd("/schema")
			local filePath = "gamemodes/"..folderName.."/"..folderName..".cfg"

			if (file.Exists(filePath, "GAME")) then
				fl.DevPrint("Importing config: "..filePath)

				config.Import(fileio.Read(filePath), CONFIG_PLUGIN)
			end
		end
	end

	if (isfunction(obj.OnPluginLoaded)) then
		obj.OnPluginLoaded(obj)
	end

	stored[obj:GetFolder()] = obj
	loadCache[obj.m_UniqueID] = true
end

function plugin.Include(folder)
	local hasMainFile = false
	local id = folder:GetFileFromFilename()
	local ext = id:GetExtensionFromFilename()
	local data = {}
	data.folder = folder
	data.id = id
	data.pluginFolder = folder

	if (reloadData[folder] == false) then
		fl.DevPrint("Not reloading plugin: "..folder)

		return
	elseif (plugin.HasLoaded(id)) then
		return
	end

	fl.DevPrint("Loading plugin: "..folder)

	if (ext != "lua") then
		if (SERVER) then
			if (file.Exists(folder.."/plugin.cfg", "LUA")) then
				local configData = config.ConfigToTable(file.Read(folder.."/plugin.cfg", "LUA"))
				local dataTable = {name = configData.name, description = configData.description, author = configData.author, depends = configData.depends}
					dataTable.pluginFolder = folder.."/plugin"
					dataTable.pluginMain = "sh_plugin.lua"

					if (file.Exists(dataTable.pluginFolder.."/sh_"..(dataTable.name or id)..".lua", "LUA")) then
						dataTable.pluginMain = "sh_"..(dataTable.name or id)..".lua"
					end
				table.Merge(data, dataTable)

				configData.name, configData.description, configData.author, configData.depends = nil, nil, nil, nil

				for k, v in pairs(configData) do
					if (v != nil) then
						config.Set(k, v)
					end
				end

				fl.sharedTable.pluginInfo[folder] = data
			end
		else
			table.Merge(data, fl.sharedTable.pluginInfo[folder])
		end
	end

	if (istable(data.depends)) then
		for k, v in ipairs(data.depends) do
			if (!plugin.Require(v)) then
				ErrorNoHalt("[Flux] Not loading the '"..tostring(folder).."' plugin! Dependency missing: '"..tostring(v).."'!\n")

				return
			end
		end
	end

	PLUGIN = Plugin(id, data)

	if (stored[folder]) then
		PLUGIN = stored[folder]
	end

	if (ext != "lua") then
		util.Include(data.pluginFolder.."/"..data.pluginMain)
	else
		if (file.Exists(folder, "LUA")) then
			util.Include(folder)
		end
	end

	plugin.IncludeFolders(data.pluginFolder)

	PLUGIN:Register()
	PLUGIN = nil

	return data
end

function plugin.IncludeSchema()
	local schemaInfo = fl.GetSchemaInfo()
	local schemaPath = schemaInfo.folder
	local schemaFolder = schemaPath.."/schema"
	local filePath = "gamemodes/"..schemaPath.."/"..schemaPath..".cfg"

	if (file.Exists(filePath, "GAME")) then
		fl.DevPrint("Checking schema dependencies using "..filePath)

		local dependencies = config.ConfigToTable(fileio.Read(filePath)).depends

		if (istable(dependencies)) then
			for k, v in ipairs(dependencies) do
				if (!plugin.Require(v)) then
					ErrorNoHalt("[Flux] Unable to load schema! Dependency missing: '"..tostring(v).."'!\n")
					ErrorNoHalt("Please install this plugin in your schema's 'plugins' folder!\n")

					return
				end
			end
		end
	end

	if (SERVER) then AddCSLuaFile(schemaPath.."/gamemode/cl_init.lua") end

	Schema = Plugin(schemaInfo.name, schemaInfo)

	util.Include(schemaFolder.."/sh_schema.lua")

	plugin.IncludeFolders(schemaFolder)
	plugin.IncludePlugins(schemaPath.."/plugins")

	if (schemaInfo.name and schemaInfo.author) then
		MsgC(Color(0, 255, 100, 255), "[Flux] ")
		MsgC(Color(255, 255, 0), schemaInfo.name)
		MsgC(Color(0, 255, 100), " by "..schemaInfo.author.." has been loaded!\n")
	end

	Schema:Register()

	hook.Run("OnSchemaLoaded")
end

-- Please specify full file name if requiring a single-file plugin.
function plugin.Require(pluginName)
	if (!isstring(pluginName)) then return false end

	if (!plugin.HasLoaded(pluginName)) then
		local searchPaths = {
			"flux/plugins/",
			(fl.GetSchemaFolder() or "flux").."/plugins/"
		}

		local tolerance = {
			"",
			"/plugin.cfg",
			".lua",
			"/plugin/sh_plugin.lua"
		}

		for k, v in ipairs(searchPaths) do
			for _, ending in ipairs(tolerance) do
				if (file.Exists(v..pluginName..ending, "LUA")) then
					plugin.Include(v..pluginName)

					return true
				end
			end
		end
	else
		return true
	end

	return false
end

function plugin.IncludePlugins(folder)
	local files, folders = file.Find(folder.."/*", "LUA")

	for k, v in ipairs(files) do
		if (v:GetExtensionFromFilename() == "lua") then
			plugin.Include(folder.."/"..v)
		end
	end

	for k, v in ipairs(folders) do
		plugin.Include(folder.."/"..v)
	end
end

do
	local entData = {
		weapons = {
			table = "SWEP",
			func = weapons.Register,
			defaultData = {
				Primary = {},
				Secondary = {},
				Base = "weapon_base"
			}
		},
		entities = {
			table = "ENT",
			func = scripted_ents.Register,
			defaultData = {
				Type = "anim",
				Base = "base_gmodentity",
				Spawnable = true
			}
		},
		effects = {
			table = "EFFECT",
			func = effects and effects.Register,
			clientside = true
		}
	}

	function plugin.IncludeEntities(folder)
		local _, dirs = file.Find(folder.."/*", "LUA")

		for k, v in ipairs(dirs) do
			if (!entData[v]) then continue end

			local dir = folder.."/"..v
			local data = entData[v]
			local files, folders = file.Find(dir.."/*", "LUA")

			for k, v in ipairs(folders) do
				local path = dir.."/"..v
				local uniqueID = (string.GetFileFromFilename(path) or ""):Replace(".lua", ""):MakeID()
				local register = false
				local var = data.table

				_G[var] = table.Copy(data.defaultData)
				_G[var].ClassName = uniqueID

				if (file.Exists(path.."/shared.lua", "LUA")) then
					util.Include(path.."/shared.lua")

					register = true
				end

				if (file.Exists(path.."/init.lua", "LUA")) then
					util.Include(path.."/init.lua")

					register = true
				end

				if (file.Exists(path.."/cl_init.lua", "LUA")) then
					util.Include(path.."/cl_init.lua")

					register = true
				end

				if (register) then
					if (data.clientside and !CLIENT) then _G[var] = nil continue end

					data.func(_G[var], uniqueID)
				end

				_G[var] = nil
			end

			for k, v in ipairs(files) do
				local path = dir.."/"..v
				local uniqueID = (string.GetFileFromFilename(path) or ""):Replace(".lua", ""):MakeID()
				local var = data.table

				_G[var] = table.Copy(data.defaultData)
				_G[var].ClassName = uniqueID

				util.Include(path)

				if (data.clientside and !CLIENT) then _G[var] = nil continue end

				data.func(_G[var], uniqueID)

				_G[var] = nil
			end
		end
	end
end

function plugin.AddExtra(strExtra)
	if (!isstring(strExtra)) then return end

	table.insert(extras, strExtra)
end

function plugin.IncludeFolders(folder)
	for k, v in ipairs(extras) do
		if (plugin.Call("PluginIncludeFolder", v, folder) == nil) then
			if (v == "entities") then
				plugin.IncludeEntities(folder.."/"..v)
			elseif (v == "themes") then
				pipeline.IncludeDirectory("theme", folder.."/themes/")
			elseif (v == "tools") then
				pipeline.IncludeDirectory("tool", folder.."/tools/")
			else
				util.IncludeDirectory(folder.."/"..v)
			end
		end
	end
end

do
	local oldHookCall = plugin.OldHookCall or hook.Call
	plugin.OldHookCall = oldHookCall

	-- If we're running the developer's mode, we should be using pcall'ed hook.Call rather than unsafe one.
	if (fl.Devmode) then
		function hook.Call(name, gm, ...)
			if (hooksCache[name]) then
				for k, v in ipairs(hooksCache[name]) do
					local success, a, b, c, d, e, f = pcall(v[1], v[2], ...)

					if (!success) then
						ErrorNoHalt("[Flux:"..(v.id or v[2]:GetName()).."] The "..name.." hook has failed to run!\n")
						ErrorNoHalt(tostring(a), "\n")

						if (name != "OnHookError") then
							hook.Call("OnHookError", gm, name, v)
						end
					elseif (a != nil) then
						return a, b, c, d, e, f
					end
				end
			end

			return oldHookCall(name, gm, ...)
		end
	else
		-- While generally a bad idea, pcall-less method is faster and if you're not developing
		-- changes are low that you'll ever run into an error anyway.
		function hook.Call(name, gm, ...)
			if (hooksCache[name]) then
				for k, v in ipairs(hooksCache[name]) do
					local a, b, c, d, e, f = v[1](v[2], ...)

					if (a != nil) then
						return a, b, c, d, e, f
					end
				end
			end

			return oldHookCall(name, gm, ...)
		end
	end

	-- This function DOES NOT call GM: (gamemode) hooks!
	-- It only calls plugin, schema and hook.Add'ed hooks!
	function plugin.Call(name, ...)
		return hook.Call(name, nil, ...)
	end
end