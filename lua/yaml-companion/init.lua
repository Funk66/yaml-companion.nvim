local M = {}

local _matchers = require("yaml-companion._matchers")
M.ctx = {}

M.setup = function(opts)
  local config = require("yaml-companion.config")
  config.setup(opts, function(client, bufnr)
    require("yaml-companion.context").setup(bufnr, client)
  end)
  M.ctx = require("yaml-companion.context")
  require("yaml-companion.log").new({ level = config.options.log_level }, true)
  return config.options.lspconfig
end

--- Set the schemas used for a buffer.
---@param bufnr number: Buffer number
---@param schemas Schema[]
---@return nil
M.set_buf_schemas = function(bufnr, schemas)
  M.ctx.schemas(bufnr, schemas)
end

--- Get the schemas used for a buffer.
---@param bufnr number: Buffer number
---@return Schema[]
M.get_buf_schemas = function(bufnr)
  return M.ctx.schemas(bufnr)
end

--- Loads a matcher.
---@param name string: Name of the matcher
M.load_matcher = function(name)
  return _matchers.load(name)
end

--- Opens a vim.ui.select menu to choose a schema
M.open_ui_select = function()
  require("yaml-companion.select.ui").open_ui_select()
end

return M
