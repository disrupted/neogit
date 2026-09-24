local config = require("neogit.config")
local diff_buffer = require("neogit.buffers.diff")

describe("buffers.diff size limit", function()
  before_each(function()
    config.values = config.get_default_values()
  end)

  local function stats(file_count, total_changes)
    return { file_count = file_count, total_changes = total_changes }
  end

  it("does not exceed when under both limits", function()
    assert.False(diff_buffer.exceeds_limit(stats(10, 100)))
  end)

  it("exceeds when the file count is over the limit", function()
    assert.True(diff_buffer.exceeds_limit(stats(101, 100)))
  end)

  it("exceeds when the changed line count is over the limit", function()
    assert.True(diff_buffer.exceeds_limit(stats(10, 5001)))
  end)

  it("treats limits of 0 as disabled", function()
    config.values.commit_editor.max_staged_diff_files = 0
    config.values.commit_editor.max_staged_diff_lines = 0
    assert.False(diff_buffer.exceeds_limit(stats(100000, 1000000)))
  end)

  it("can disable a single limit", function()
    config.values.commit_editor.max_staged_diff_files = 0
    assert.False(diff_buffer.exceeds_limit(stats(100000, 100)))
    assert.True(diff_buffer.exceeds_limit(stats(1, 5001)))
  end)
end)
