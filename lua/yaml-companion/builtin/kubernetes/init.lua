local M = { name = "kubernetes" }

local api = vim.api
local resources = require("yaml-companion.builtin.kubernetes.resources")
local version = require("yaml-companion.builtin.kubernetes.version")
local uri = "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/"
  .. version
  .. "-standalone-strict/all.json"

local schema = {
  name = "Kubernetes",
  uri = uri,
}

M.parse = function(bufnr)
  local kinds = {}
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    if vim.regex("^kind: "):match_str(line) then
      table.insert(kinds, vim.split(line, " ")[2])
    end
  end
  return kinds
end

M.match = function(bufnr)
  for _, kind in ipairs(M.parse(bufnr)) do
    for _, resource in ipairs(resources) do
      if kind == resource then
        return { schema }
      end
    end
  end
end

M.handles = function()
  return { schema }
end

return M
