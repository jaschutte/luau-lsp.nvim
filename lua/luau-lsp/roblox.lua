local async = require "plenary.async"
local compat = require "luau-lsp.compat"
local config = require "luau-lsp.config"
local curl = require "plenary.curl"
local log = require "luau-lsp.log"
local util = require "luau-lsp.util"

local API_DOCS =
  "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/api-docs/en-us.json"
local SECURITY_LEVELS = {
  "None",
  "LocalUserSecurity",
  "PluginSecurity",
  "RobloxScriptSecurity",
}

local function global_types_url(security_level)
  return string.format(
    "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.%s.d.luau",
    security_level
  )
end

local function global_types_file(security_level)
  return util.storage_file(string.format("globalTypes.%s.d.luau", security_level))
end

local function api_docs_file()
  return util.storage_file "api-docs.json"
end

local M = {}

---@type fun():string?,string?
M.download_api = async.wrap(function(callback)
  local security_level = config.get().types.roblox_security_level

  assert(
    compat.list_contains(SECURITY_LEVELS, security_level),
    "invalid security level: " .. security_level
  )

  local on_download = util.fcounter(2, function()
    callback(global_types_file(security_level), api_docs_file())
  end)

  local on_error = util.fcounter(2, function()
    if
      compat.uv.fs_stat(global_types_file(security_level)) and compat.uv.fs_stat(api_docs_file())
    then
      log.error "Could not download roblox types, using local files"
      callback(global_types_file(security_level), api_docs_file())
      return
    end

    log.error "Could not download roblox types, no local files found"
    callback(nil, nil)
  end)

  curl.get(API_DOCS, {
    output = api_docs_file(),
    callback = on_download,
    on_error = on_error,
    compressed = false,
  })

  curl.get(global_types_url(security_level), {
    output = global_types_file(security_level),
    callback = on_download,
    on_error = on_error,
    compressed = false,
  })
end, 1)

return M
