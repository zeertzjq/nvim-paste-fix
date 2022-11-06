local tdots, tick, got_line1, undo_started, trailing_nl = 0, 0, false, false, false

function vim.paste(lines, phase)
  local now = vim.loop.now()
  local is_first_chunk = phase < 2
  local is_last_chunk = phase == -1 or phase == 3
  if is_first_chunk then -- Reset flags.
    tdots, tick, got_line1, undo_started, trailing_nl = now, 0, false, false, false
  end
  if #lines == 0 then
    lines = { '' }
  end
  if #lines == 1 and lines[1] == '' and not is_last_chunk then
    -- An empty chunk can cause some edge cases in streamed pasting,
    -- so don't do anything unless it is the last chunk.
    return true
  end
  -- Note: mode doesn't always start with "c" in cmdline mode, so use getcmdtype() instead.
  if vim.fn.getcmdtype() ~= '' then -- cmdline-mode: paste only 1 line.
    if not got_line1 then
      got_line1 = (#lines > 1)
      -- Escape control characters
      local line1 = lines[1]:gsub('(%c)', '\022%1')
      -- nvim_input() is affected by mappings,
      -- so use nvim_feedkeys() with "n" flag to ignore mappings.
      -- "t" flag is also needed so the pasted text is saved in cmdline history.
      vim.api.nvim_feedkeys(line1, 'nt', true)
    end
    return true
  end
  local mode = vim.api.nvim_get_mode().mode
  if undo_started then
    vim.api.nvim_command('undojoin')
  end
  if mode:find('^i') or mode:find('^n?t') then -- Insert mode or Terminal buffer
    vim.api.nvim_put(lines, 'c', false, true)
  elseif phase < 2 and mode:find('^R') and not mode:find('^Rv') then -- Replace mode
    -- TODO: implement Replace mode streamed pasting
    -- TODO: support Virtual Replace mode
    local nchars = 0
    for _, line in ipairs(lines) do
      nchars = nchars + line:len()
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local bufline = vim.api.nvim_buf_get_lines(0, row - 1, row, true)[1]
    local firstline = lines[1]
    firstline = bufline:sub(1, col) .. firstline
    lines[1] = firstline
    lines[#lines] = lines[#lines] .. bufline:sub(col + nchars + 1, bufline:len())
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)
  elseif mode:find('^[nvV\22sS\19]') then -- Normal or Visual or Select mode
    if mode:find('^n') then -- Normal mode
      -- When there was a trailing new line in the previous chunk,
      -- the cursor is on the first character of the next line,
      -- so paste before the cursor instead of after it.
      vim.api.nvim_put(lines, 'c', not trailing_nl, false)
    else -- Visual or Select mode
      vim.api.nvim_command([[exe "silent normal! \<Del>"]])
      local del_start = vim.fn.getpos("'[")
      local cursor_pos = vim.fn.getpos('.')
      if mode:find('^[VS]') then -- linewise
        if cursor_pos[2] < del_start[2] then -- replacing lines at eof
          -- create a new line
          vim.api.nvim_put({ '' }, 'l', true, true)
        end
        vim.api.nvim_put(lines, 'c', false, false)
      else
        -- paste after cursor when replacing text at eol, otherwise paste before cursor
        vim.api.nvim_put(lines, 'c', cursor_pos[3] < del_start[3], false)
      end
    end
    -- put cursor at the end of the text instead of one character after it
    vim.fn.setpos('.', vim.fn.getpos("']"))
    trailing_nl = lines[#lines] == ''
  else -- Don't know what to do in other modes
    return false
  end
  undo_started = true
  if phase ~= -1 and (now - tdots >= 100) then
    local dots = ('.'):rep(tick % 4)
    tdots = now
    tick = tick + 1
    -- Use :echo because Lua print('') is a no-op, and we want to clear the
    -- message when there are zero dots.
    vim.api.nvim_command(('echo "%s"'):format(dots))
  end
  if is_last_chunk then
    vim.api.nvim_command('redraw' .. (tick > 1 and '|echo ""' or ''))
  end
  return true -- Paste will not continue if not returning `true`.
end

if vim.fn == nil then
  vim.fn = setmetatable({}, {
    __index = function(t, key)
      local _fn
      _fn = function(...)
        return vim.api.nvim_call_function(key, { ... })
      end
      t[key] = _fn
      return _fn
    end,
  })
end
