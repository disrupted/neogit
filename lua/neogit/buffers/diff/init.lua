local Buffer = require("neogit.lib.buffer")
local ui = require("neogit.buffers.diff.ui")
local git = require("neogit.lib.git")
local config = require("neogit.config")

local api = vim.api

---@class DiffBuffer
---@field buffer Buffer
---@field open fun(self): DiffBuffer
---@field close fun()
---@field stats table
---@field diffs table|nil
---@field disabled boolean
---@field header string
---@see Buffer
---@see Ui
local M = {}
M.__index = M

--- True when the staged changeset is too large to load and render without
--- freezing the editor. Either limit can be disabled by setting it to 0.
---@param stats DiffStagedStats
---@return boolean
function M.exceeds_limit(stats)
  local max_files = config.values.commit_editor.max_staged_diff_files or 0
  local max_lines = config.values.commit_editor.max_staged_diff_lines or 0

  if max_files > 0 and (stats.file_count or 0) > max_files then
    return true
  end

  if max_lines > 0 and (stats.total_changes or 0) > max_lines then
    return true
  end

  return false
end

---@param header string
---@return DiffBuffer
function M:new(header)
  local instance = {
    buffer = nil,
    header = header,
    stats = git.diff.staged_stats(),
    diffs = nil,
    disabled = false,
  }

  setmetatable(instance, self)
  return instance
end

--- Closes the DiffBuffer
function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end
end

--- Loads the staged diffs. Kept lazy so large changesets can be skipped.
local function load_diffs()
  return vim.tbl_map(function(item)
    return item.diff
  end, git.repo.state.staged.items)
end

--- Loads and renders the full diff, replacing the placeholder. Invoked from the
--- placeholder's force-load mapping.
function M:load_full_diff()
  if self.diffs or not self.buffer then
    return
  end

  self.disabled = false
  self.diffs = load_diffs()

  self.buffer.ui:render(unpack(ui.DiffView(self.header, self.stats, self.diffs)))
  self.buffer:win_call(function()
    vim.cmd("normal! zR")
  end)
end

---Opens the DiffBuffer
---If already open will close the buffer
---@param force? boolean Load the diffs even when over the configured limit
---@return DiffBuffer
function M:open(force)
  if vim.tbl_isempty(self.stats.files) then
    return self
  end

  self.disabled = not force and M.exceeds_limit(self.stats)

  if not self.disabled and not self.diffs then
    self.diffs = load_diffs()
  end

  local status_maps = config.get_reversed_status_maps()

  local mappings = {
    ["{"] = function() -- Goto Previous
      local function previous_hunk_header(self, line)
        local c = self.buffer.ui:get_component_on_line(line, function(c)
          return c.options.tag == "Diff" or c.options.tag == "Hunk"
        end)

        if c then
          local first, _ = c:row_range_abs()
          if vim.fn.line(".") == first then
            first = previous_hunk_header(self, line - 1)
          end

          return first
        end
      end

      local previous_header = previous_hunk_header(self, vim.fn.line("."))
      if previous_header then
        api.nvim_win_set_cursor(0, { previous_header, 0 })
        vim.cmd("normal! zt")
      end
    end,
    ["}"] = function() -- Goto next
      local c = self.buffer.ui:get_component_under_cursor(function(c)
        return c.options.tag == "Diff" or c.options.tag == "Hunk"
      end)

      if c then
        if c.options.tag == "Diff" then
          self.buffer:move_cursor(vim.fn.line(".") + 1)
        else
          local _, last = c:row_range_abs()
          if last == vim.fn.line("$") then
            self.buffer:move_cursor(last)
          else
            self.buffer:move_cursor(last + 1)
          end
        end
        vim.cmd("normal! zt")
      end
    end,
    [status_maps["Toggle"]] = function()
      pcall(vim.cmd, "normal! za")
    end,
    [status_maps["Close"]] = function()
      self:close()
    end,
  }

  if self.disabled then
    mappings["<cr>"] = function()
      self:load_full_diff()
    end
  end

  self.buffer = Buffer.create {
    name = "NeogitDiffView",
    filetype = "NeogitDiffView",
    status_column = not config.values.disable_signs and "" or nil,
    kind = config.values.commit_editor.staged_diff_split_kind,
    context_highlight = not config.values.disable_context_highlighting and config.values.log_pager == nil,
    mappings = { n = mappings },
    render = function()
      if self.disabled then
        return ui.DiffViewPlaceholder(self.header, self.stats)
      end

      return ui.DiffView(self.header, self.stats, self.diffs or {})
    end,
    after = function()
      vim.cmd("normal! zR")
      vim.wo.colorcolumn = ""
    end,
  }

  return self
end

return M
