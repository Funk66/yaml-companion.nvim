local M = {}

local matchers = require("yaml-companion._matchers")._loaded
local schema = require("yaml-companion.schema")

local log = require("yaml-companion.log")

---@type { client: vim.lsp.Client, schemas: Schema[], executed: boolean}[]
M.ctxs = {}
M.initialized_client_ids = {}

---@param bufnr number
---@param client vim.lsp.Client
---@return Schema[] | nil
M.autodiscover = function(bufnr, client)
  if not M.ctxs[bufnr] then
    log.fmt_error("bufnr=%d client_id=%d doesn't exists", bufnr, client.id)
    return
  end

  if not M.initialized_client_ids[client.id] then
    log.fmt_debug("bufnr=%d client_id=%d is not yet initialized", bufnr, client.id)
    return
  end

  if M.ctxs[bufnr].executed then
    log.fmt_debug("bufnr=%d client_id=%d already executed", bufnr, client.id)
    return M.ctxs[bufnr].schemas
  end

  M.ctxs[bufnr].executed = true
  local current_schema = schema.current(bufnr)

  -- if LSP returns a name that means it came from SchemaStore
  -- and we can use it right away
  if current_schema.name and current_schema.uri ~= schema.default().uri then
    M.ctxs[bufnr].schemas = current_schema
    log.fmt_debug(
      "bufnr=%d client_id=%d schema=%s an SchemaStore defined schema matched this file",
      bufnr,
      client.id,
      schema.name
    )
    return M.ctxs[bufnr].schemas

    -- if it returned something without a name it means it came from our own
    -- internal schema table and we have to loop through it to get the name
  else
    for _, option_schema in ipairs(schema.from_options()) do
      if option_schema.uri == current_schema.uri then
        M.ctxs[bufnr].schemas = option_schema
        log.fmt_debug(
          "bufnr=%d client_id=%d schema=%s an user defined schema matched this file",
          bufnr,
          client.id,
          option_schema.name
        )
        return M.ctxs[bufnr].schemas
      end
    end
    log.fmt_debug(
      "bufnr=%d client_id=%d no user defined schema matched this file",
      bufnr,
      client.id
    )
  end

  -- if LSP is not using any schema, use registered matchers
  for _, matcher in pairs(matchers) do
    local results = matcher.match(bufnr)
    if results then
      local schemas = {}
      for key, result in pairs(results) do
        schemas[key] = result
      end
      M.schemas(bufnr, schemas)
      log.fmt_debug(
        "bufnr=%d client_id=%d matcher=%s a registered matcher matched this file",
        bufnr,
        client.id,
        matcher.name
      )
      return M.ctxs[bufnr].schemas
    end

    log.fmt_debug("bufnr=%d client_id=%d no registered matcher matched this file", bufnr, client.id)
  end

  -- No schema matched
  log.fmt_debug("bufnr=%d client_id=%d no registered schema matches", bufnr, client.id)

  return {}
end

---@param bufnr number
---@param client vim.lsp.Client
M.setup = function(bufnr, client)
  if client.name ~= "yamlls" then
    return
  end

  -- The server does support formatting but it is disabled by default
  -- https://github.com/redhat-developer/yaml-language-server/issues/486
  if require("yaml-companion.config").options.formatting then
    client.server_capabilities.documentFormattingProvider = true
    client.server_capabilities.documentRangeFormattingProvider = true
  end

  -- remove yamlls from not yaml files
  -- https://github.com/towolf/vim-helm/issues/15
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "helm" then
    vim.diagnostic.enable(false, { bufnr = bufnr })
    vim.defer_fn(function()
      vim.diagnostic.reset(nil, bufnr)
    end, 1000)
    vim.lsp.buf_detach_client(bufnr, client.id)
  end

  local state = {
    client = client,
    schema = schema.default(),
    executed = false,
  }

  M.ctxs[bufnr] = state

  -- The first time this won't work because the client is not initialized yet
  -- but it will be called once per client from the initialized_handler when it is.
  M.autodiscover(bufnr, client)
end

--- gets or sets the schemas in its context and lsp
---@param bufnr number
---@param new_schemas Schema[] | nil
---@return Schema[]
M.schemas = function(bufnr, new_schemas)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if M.ctxs[bufnr] == nil then
    return { schema.default() }
  end

  if new_schemas == nil then
    return M.ctxs[bufnr].schemas
  end

  local valid_schemas = {}
  for _, new_schema in pairs(new_schemas) do
    if new_schema and new_schema.uri and new_schema.name then
      table.insert(valid_schemas, new_schema)
    end
  end

  local bufuri = vim.uri_from_bufnr(bufnr)
  local client = M.ctxs[bufnr].client
  local settings = client.settings
  local override = {}

  for key, _ in pairs(settings.yaml.schemas) do
    if settings.yaml.schemas[key] == bufuri then
      settings.yaml.schemas[key] = nil
    end
  end

  for _, valid_schema in pairs(valid_schemas) do
    table.insert(M.ctxs[bufnr], valid_schema)
    override[valid_schema.uri] = bufuri
    log.fmt_debug("file=%s schema=%s set new override", bufuri, valid_schema.uri)
  end

  settings = vim.tbl_deep_extend("force", settings, { yaml = { schemas = override } })
  client.settings = vim.tbl_deep_extend("force", settings, { yaml = { schemas = override } })
  client.workspace_did_change_configuration(client.settings)
end

return M
