local M = {}

M.setup = function(opts)
  local opts = opts or {}
  M.histfile = opts.histfile or "$HOME/.bash_history"
  M.pastCommandsCount = opts.pastCommandsCount or 100
  M.filter = opts.filter or function(line) return true end
  return M
end

M.reconfig = function(opts)
  local opts = opts or {}
  M.histfile = opts.histfile or M.histfile
  M.pastCommandsCount = opts.pastCommandsCount or M.pastCommandsCount
  return M
end

M.popup = function(cb)
  local handle = io.popen("tail -n " .. M.pastCommandsCount .. " " .. M.histfile .. " | uniq")
  local result = handle:read("*a")
  handle:close()

  local results = vim.split(result, "\n")
  if #results ~= 0 and results[#results] == "" then
    table.remove(results, #results)
  end

  results = vim.tbl_filter(M.filter, results)

  local width = .95
  local height = 10

  local ui = vim.api.nvim_list_uis()[1]

  local opts = {
    relative = "editor",
    width = math.floor(ui.width * width),
    height = height,
    col = (ui.width/2) - math.floor(ui.width * width/2),
    row = (ui.height/2) - (height/2),
    anchor = "NW",
    style = "minimal",
    border = "single",
  }

  local buf = vim.api.nvim_create_buf(true, false)
  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Cleanup the buffer once it is hidden (no window shows it).
  vim.api.nvim_create_autocmd("BufHidden", {
    buffer = buf,
    callback = function(ev) 
      vim.schedule(function()
	vim.cmd("bd! " .. buf)
      end)
      -- Return true to delete this autocommand after it triggers.
      return true
    end
  })

  vim.keymap.set("n", "<cr>", function()
    local cursor = vim.api.nvim_win_get_cursor(win)[1]
    local line = vim.api.nvim_buf_get_lines(buf, cursor - 1, cursor, true)[1]
    cb(line)
    vim.api.nvim_win_close(win, true)
  end, {buffer = buf})

  vim.keymap.set("x", "<cr>", function()
    local lines = {}
    local mode = vim.call("mode")
    local start = vim.call("getpos", "v")
    local final = vim.call("getpos", ".")
    if start[2] > final[2] or (start[2] == final[2] and start[3] > final[3]) then
      start, final = final, start
    end
    if mode == "v" then -- Visual Mode
      lines = vim.api.nvim_buf_get_text(buf, start[2] - 1, start[3] - 1, final[2] - 1, final[3], {})
    elseif mode == "V" then -- Visual Line Mode
      lines = vim.api.nvim_buf_get_lines(buf, start[2] - 1, final[2], true)
    elseif mode == "" then -- Visual Block Mode
      lines = vim.api.nvim_buf_get_lines(buf, start[2] - 1, final[2], true)
      local left  = start[3] < final[3] and start[3] or final[3]
      local right = start[3] > final[3] and start[3] or final[3]
      for i, v in ipairs(lines) do
	lines[i] = string.sub(v, left, right)
      end
    else
      print("Warning: Unknown visual mode: '" .. mode .. "'")
    end

    cb(table.concat(lines, "\n"))
    vim.api.nvim_win_close(win, true)
  end, {buffer = buf})

  vim.api.nvim_buf_set_lines(buf, 0, 1, true, results)

  vim.cmd("normal G")
end

return M
