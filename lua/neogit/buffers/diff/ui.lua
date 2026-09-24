local M = {}

local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")
local common_ui = require("neogit.buffers.common")

local Diff = common_ui.Diff
local EmptyLine = common_ui.EmptyLine
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

function M.OverviewFile(file_padding)
  return function(file)
    return row.tag("OverviewFile") {
      text.highlight("NeogitFilePath")(util.pad_right(file.path, file_padding)),
      text("  | "),
      text.highlight("Number")(util.pad_left(file.changes or "0", 5)),
      text("  "),
      text.highlight("NeogitDiffAdditions")(file.insertions),
      text.highlight("NeogitDiffDeletions")(file.deletions),
    }
  end
end

function M.DiffView(header, stats, diffs)
  local file_padding = util.max_length(map(diffs, function(diff)
    return diff.file
  end))

  return {
    text.highlight("NeogitFloatHeaderHighlight")(header),
    text(stats.summary),
    col(map(stats.files, M.OverviewFile(file_padding)), { tag = "OverviewFileList" }),
    EmptyLine(),
    col(map(diffs, Diff), { tag = "DiffList" }),
  }
end

--- A lightweight stand-in for `DiffView` used when the staged changeset is too
--- large to load and render without freezing. Shows the cheap stats summary and
--- offers a hint to force-load the full diff.
function M.DiffViewPlaceholder(header, stats)
  return {
    text.highlight("NeogitFloatHeaderHighlight")(header),
    text(stats.summary or ""),
    EmptyLine(),
    text.highlight("NeogitDiffDeletions")("Staged changes are too large to display."),
    text(
      ("Skipped the diff preview to avoid freezing the editor (%d file%s, %d changed line%s)."):format(
        stats.file_count or 0,
        (stats.file_count or 0) == 1 and "" or "s",
        stats.total_changes or 0,
        (stats.total_changes or 0) == 1 and "" or "s"
      )
    ),
    EmptyLine(),
    text("Press <cr> to load the full diff anyway."),
    text("See :help neogit-configuration for max_staged_diff_files / max_staged_diff_lines."),
  }
end
return M
