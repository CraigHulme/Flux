fl = fl or {}
fl.start_time = os.clock()

function safe_require(mod)
  local success, value = pcall(require, mod)

  if !success then
    ErrorNoHalt('Failed to open the "'..mod..'" module!\n')
    return false
  end

  return true
end

if fl.initialized then
  if LITE_REFRESH then
    MsgC(Color(0, 255, 100, 255), 'Schema auto-reload in progress...\n')
  else
    MsgC(Color(0, 255, 100, 255), 'Lua auto-reload in progress...\n')
  end
end

if !LITE_REFRESH then
  if !safe_require 'fileio' then
    ErrorNoHalt('The fileio module has failed to load!\nPlease make sure that you have gmsv_fileio_'..((system.IsWindows() and 'win32') or 'linux')..'.dll in garrysmod/lua/bin folder!\nAborting startup...\n')
    return
  end

  -- Put that under an if because it doesn't change.
  if !string.utf8len or !pon or !netstream then
    AddCSLuaFile 'thirdparty/utf8.lua'
    AddCSLuaFile 'thirdparty/pon.lua'
    AddCSLuaFile 'thirdparty/netstream.lua'
  end

  AddCSLuaFile 'shared.lua'

  -- Include pON, Netstream and UTF-8 library.
  if !string.utf8len or !pon or !netstream or !YAML then
    include 'thirdparty/utf8.lua'
    include 'thirdparty/pon.lua'
    include 'thirdparty/netstream.lua'
    YAML = include 'thirdparty/yaml.lua'

    Settings = Settings or YAML.read('gamemodes/flux/config/settings.yml')
    Settings.database = YAML.read('gamemodes/flux/config/database.yml')
  end
end

-- Initiate shared boot.
include 'shared.lua'

if fl.initialized then
  MsgC(Color(0, 255, 100, 255), 'Auto-reloaded in '..math.Round(os.clock() - fl.start_time, 3).. ' second(s)\n')
else
  MsgC(Color(0, 255, 100, 255), 'Flux v'..GM.version..' ('..GM.code_name..') has finished loading in '..math.Round(os.clock() - fl.start_time, 3).. ' second(s)\n')
  fl.initialized = true
end
