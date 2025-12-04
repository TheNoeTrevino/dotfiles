# TreeSitter Plugin Architecture Expert

Expert in building high-performance Neovim plugins using nvim-treesitter. Specializes in module systems, query-based parsing, virtual text manipulation, and performance optimization patterns derived from nvim-treesitter and todo-comments.nvim codebases.

## Core Architecture Patterns

### 1. Module System Architecture

**Three-Tier Plugin Structure:**
```
your-plugin/
├── plugin/your-plugin.lua          # Minimal entry point (VimL commands only)
├── lua/your-plugin/
│   ├── init.lua                    # Main module with setup()
│   ├── config.lua                  # Configuration management
│   ├── highlight.lua               # Display logic (extmarks/virtual text)
│   └── query.lua                   # TreeSitter query execution
└── queries/
    └── go/
        └── custom-queries.scm      # TreeSitter query definitions
```

**Entry Point Pattern (plugin/your-plugin.lua):**
```lua
-- Lazy load protection
if vim.g.loaded_your_plugin then
  return
end
vim.g.loaded_your_plugin = true

-- Define commands that load on-demand
command! YourPluginToggle lua require("your-plugin").toggle()
command! YourPluginEnable lua require("your-plugin").enable()
```

**Module Registration with nvim-treesitter:**
```lua
-- lua/your-plugin/init.lua
local M = {}

function M.setup(opts)
  -- Register as treesitter module
  require('nvim-treesitter').define_modules({
    your_plugin = {
      module_path = 'your-plugin',
      enable = opts.enable or false,
      is_supported = function(lang)
        return lang == "go"  -- Or your target language
      end,
      attach = M.attach,
      detach = M.detach,
    }
  })
end

function M.attach(bufnr, lang)
  -- Called when module is enabled for a buffer
  local ns_id = vim.api.nvim_create_namespace('your-plugin')
  M.update_display(bufnr, ns_id)

  -- Set up incremental updates
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    buffer = bufnr,
    callback = function()
      M.debounced_update(bufnr, ns_id)
    end,
  })
end

function M.detach(bufnr)
  -- Cleanup when disabled
  local ns_id = vim.api.nvim_get_namespaces()['your-plugin']
  if ns_id then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

return M
```

### 2. Configuration Management

**Deep Merge Pattern (from todo-comments.nvim):**
```lua
-- lua/your-plugin/config.lua
local M = {}

M.ns = vim.api.nvim_create_namespace("your-plugin")
M.options = {}
M.loaded = false

local defaults = {
  enable = false,
  languages = { "go" },
  display = {
    icon = "⚠",
    style = "eol",  -- 'eol' or 'overlay'
    throttle = 200,  -- ms delay for updates
  },
  patterns = {
    error_check = true,
    error_wrap = true,
  },
}

function M.setup(options)
  -- Defer setup if vim not fully loaded
  if vim.api.nvim_get_vvar("vim_did_enter") == 0 then
    vim.defer_fn(function()
      M._setup(options)
    end, 0)
  else
    M._setup(options)
  end
end

function M._setup(options)
  -- Deep merge user options with defaults
  M.options = vim.tbl_deep_extend("force", {}, defaults, M.options or {}, options or {})

  -- Initialize display
  M.setup_highlights()
  M.loaded = true
end

function M.setup_highlights()
  -- Define highlight groups
  vim.api.nvim_set_hl(0, "YourPluginError", {
    fg = "#DC2626",
    bold = true,
  })
  vim.api.nvim_set_hl(0, "YourPluginInfo", {
    fg = "#2563EB",
  })
end

return M
```

**Deferred Initialization Pattern:**
- Store options immediately but delay processing
- Use `vim.defer_fn()` if vim hasn't entered yet
- Allows fast startup while ensuring proper initialization order

### 3. TreeSitter Query System

**Query Definition (queries/go/error-collapse.scm):**
```scheme
; Match Go error check patterns

; Standard if err != nil { return ... }
((if_statement
  condition: (binary_expression
    left: (identifier) @error.var
    operator: "!="
    right: (nil))
  consequence: (block
    (return_statement) @error.return)) @error.block
  (#eq? @error.var "err"))

; Error wrap: fmt.Errorf("context: %w", err)
(call_expression
  function: (selector_expression
    operand: (identifier) @_pkg
    field: (field_identifier) @_func)
  arguments: (argument_list
    (interpreted_string_literal) @error.format
    (identifier) @_err)
  (#eq? @_pkg "fmt")
  (#any-of? @_func "Errorf" "Errorf")
  (#eq? @_err "err")) @error.wrap

; Direct error return
((if_statement
  condition: (binary_expression
    left: (identifier) @_err
    operator: "!="
    right: (nil))
  consequence: (block
    (return_statement
      (expression_list
        (identifier) @error.direct)))) @error.simple
  (#eq? @_err "err")
  (#eq? @error.direct "err"))
```

**Query Execution Pattern:**
```lua
-- lua/your-plugin/query.lua
local M = {}
local ts = vim.treesitter
local parsers = require('nvim-treesitter.parsers')

function M.get_error_nodes(bufnr)
  -- Get parser for buffer
  local parser = parsers.get_parser(bufnr, "go")
  if not parser then
    return {}
  end

  -- Get query
  local query = ts.query.get("go", "error-collapse")
  if not query then
    return {}
  end

  local matches = {}

  -- Iterate over syntax trees
  parser:for_each_tree(function(tree, lang_tree)
    local root = tree:root()

    -- Execute query
    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
      local capture_name = query.captures[id]

      table.insert(matches, {
        node = node,
        capture = capture_name,
        metadata = metadata,
      })
    end
  end)

  return matches
end

-- Extract text from node
function M.get_node_text(node, bufnr)
  local start_row, start_col, end_row, end_col = node:range()

  if start_row == end_row then
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
    return line:sub(start_col + 1, end_col)
  else
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
    lines[1] = lines[1]:sub(start_col + 1)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    return table.concat(lines, "\n")
  end
end

return M
```

**Viewport-Limited Query Execution:**
```lua
function M.get_visible_error_nodes(bufnr, win)
  win = win or vim.api.nvim_get_current_win()

  -- Get visible range
  local start_line = vim.fn.line('w0', win) - 1
  local end_line = vim.fn.line('w$', win)

  local parser = parsers.get_parser(bufnr, "go")
  local query = ts.query.get("go", "error-collapse")

  if not parser or not query then
    return {}
  end

  local matches = {}

  parser:for_each_tree(function(tree)
    local root = tree:root()

    for id, node in query:iter_captures(root, bufnr, start_line, end_line) do
      local capture_name = query.captures[id]
      table.insert(matches, {
        node = node,
        capture = capture_name,
      })
    end
  end)

  return matches
end
```

### 4. Virtual Text Display Patterns

**Extmark-Based Virtual Text:**
```lua
-- lua/your-plugin/display.lua
local M = {}
local config = require('your-plugin.config')

function M.show_error_summary(bufnr, line, error_info)
  local ns_id = config.ns

  -- Different display styles
  if config.options.display.style == "eol" then
    -- End of line annotation
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, {
      virt_text = {{' → ' .. error_info.message, 'YourPluginError'}},
      virt_text_pos = 'eol',
      hl_mode = 'combine',
      priority = 100,
    })
  elseif config.options.display.style == "overlay" then
    -- Replace actual code with collapsed view
    local start_col = error_info.start_col or 0
    local end_col = error_info.end_col or -1

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, start_col, {
      virt_text = {{error_info.collapsed_text, 'YourPluginInfo'}},
      virt_text_pos = 'overlay',
      end_col = end_col,
      conceal = '',
    })
  end
end

-- Clear all virtual text for buffer
function M.clear_display(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, config.ns, 0, -1)
end

-- Update only specific range
function M.update_range(bufnr, start_line, end_line)
  local ns_id = config.ns

  -- Clear range
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, start_line, end_line + 1)

  -- Re-apply virtual text for this range
  local errors = require('your-plugin.query').get_error_nodes(bufnr)

  for _, error in ipairs(errors) do
    local row = error.node:start()
    if row >= start_line and row <= end_line then
      M.show_error_summary(bufnr, row, error)
    end
  end
end

return M
```

**Multi-Line Collapsed Display:**
```lua
function M.collapse_error_block(bufnr, start_row, end_row, summary)
  local ns_id = config.ns

  -- First line: show summary
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, 0, {
    virt_text = {{config.options.display.icon .. ' ' .. summary, 'YourPluginError'}},
    virt_text_pos = 'eol',
  })

  -- Hide intermediate lines with concealment
  for row = start_row + 1, end_row do
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, 0, {
      virt_text = {{'  ...', 'Comment'}},
      virt_text_pos = 'overlay',
      conceal = '',
    })
  end
end
```

### 5. Performance Optimization Patterns

**Buffer Tick Memoization (from nvim-treesitter):**
```lua
-- lua/your-plugin/cache.lua
local M = {}

function M.memoize_by_buf_tick(fn)
  local cache = setmetatable({}, { __mode = "kv" })

  return function(bufnr)
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)

    -- Return cached if tick matches
    if cache[bufnr] and cache[bufnr].tick == tick then
      return cache[bufnr].result
    end

    -- Attach cleanup on first access
    if not cache[bufnr] then
      vim.api.nvim_buf_attach(bufnr, false, {
        on_detach = function()
          cache[bufnr] = nil
          return true
        end,
      })
    end

    -- Compute and cache
    local result = fn(bufnr)
    cache[bufnr] = {
      result = result,
      tick = tick,
    }

    return result
  end
end

-- Usage:
local get_cached_errors = M.memoize_by_buf_tick(function(bufnr)
  return require('your-plugin.query').get_error_nodes(bufnr)
end)
```

**Throttled Updates (from todo-comments.nvim):**
```lua
-- lua/your-plugin/update.lua
local M = {}

M.timer = vim.uv.new_timer()

function M.throttled_update(bufnr, ns_id, delay)
  delay = delay or require('your-plugin.config').options.display.throttle

  if not M.timer:is_active() then
    M.timer:start(delay, 0, vim.schedule_wrap(function()
      M.do_update(bufnr, ns_id)
    end))
  end
end

function M.do_update(bufnr, ns_id)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local display = require('your-plugin.display')
  display.clear_display(bufnr)

  -- Get errors and update display
  local errors = require('your-plugin.query').get_error_nodes(bufnr)
  for _, error in ipairs(errors) do
    local row = error.node:start()
    display.show_error_summary(bufnr, row, error)
  end
end

return M
```

**Incremental State Tracking (from todo-comments.nvim):**
```lua
-- Track which lines are valid/need update
M.state = {}

function M.get_state(bufnr)
  if not M.state[bufnr] then
    M.state[bufnr] = {
      valid = {},  -- valid[line_num] = true
      extmarks = {},  -- extmarks[line_num] = extmark_id
    }
  end
  return M.state[bufnr]
end

function M.invalidate_range(bufnr, first, last)
  local state = M.get_state(bufnr)

  if first == 0 and last == -1 then
    -- Full invalidation
    state.valid = {}
  else
    -- Partial invalidation with context
    local context = 10  -- lines of context
    first = math.max(first - context, 0)
    last = math.min(last + context, vim.api.nvim_buf_line_count(bufnr))

    for i = first, last do
      state.valid[i] = nil
    end
  end

  M.schedule_update(bufnr)
end

-- Only update invalid lines
function M.update_invalid_lines(bufnr)
  local state = M.get_state(bufnr)
  local display = require('your-plugin.display')

  -- Get visible range
  local first = vim.fn.line('w0') - 1
  local last = vim.fn.line('w$')

  -- Find invalid lines in visible range
  local to_update = {}
  for i = first, last do
    if not state.valid[i] then
      table.insert(to_update, i)
    end
  end

  if #to_update > 0 then
    display.update_range(bufnr, to_update[1], to_update[#to_update])

    -- Mark as valid
    for _, line in ipairs(to_update) do
      state.valid[line] = true
    end
  end
end
```

**Buffer Attachment with Auto-Cleanup:**
```lua
function M.attach_to_buffer(bufnr)
  local state = M.get_state(bufnr)

  if state.attached then
    return
  end

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_event, _buf, _tick, first, _last, last_new)
      -- Invalidate changed lines
      M.invalidate_range(bufnr, first, last_new)
    end,
    on_reload = function()
      -- Full invalidation on reload
      M.invalidate_range(bufnr, 0, -1)
    end,
    on_detach = function()
      -- Cleanup
      M.state[bufnr] = nil
      return true
    end,
  })

  state.attached = true
end
```

### 6. Go Error Handling Specific Patterns

**Error Pattern Detection:**
```lua
-- lua/your-plugin/go-errors.lua
local M = {}

function M.analyze_error_block(node, bufnr)
  local query = require('your-plugin.query')

  -- Get the error check node
  local err_check = node
  local start_row, _, end_row, _ = err_check:range()

  -- Find return statement within the block
  local return_node = nil
  for child in node:iter_children() do
    if child:type() == "return_statement" then
      return_node = child
      break
    end
  end

  if not return_node then
    return nil
  end

  -- Extract return values
  local return_text = query.get_node_text(return_node, bufnr)

  -- Check for fmt.Errorf wrapping
  local is_wrapped = return_text:match("fmt%.Errorf")
  local error_msg = "err"

  if is_wrapped then
    -- Extract format string
    local format = return_text:match('"([^"]+)"')
    if format then
      error_msg = format:gsub("%%w", "err"):gsub("%%v", "")
    end
  end

  return {
    start_row = start_row,
    end_row = end_row,
    message = error_msg,
    is_wrapped = is_wrapped,
    original_text = query.get_node_text(node, bufnr),
  }
end

function M.format_collapsed_view(error_info)
  if error_info.is_wrapped then
    return string.format("if err != nil : %s 󱞿", error_info.message)
  else
    return "if err != nil : err 󱞿"
  end
end

return M
```

**Full Integration Example:**
```lua
-- lua/your-plugin/init.lua
local M = {}
local config = require('your-plugin.config')

function M.setup(opts)
  config.setup(opts)

  -- Register with nvim-treesitter if available
  local ok, ts = pcall(require, 'nvim-treesitter')
  if ok then
    ts.define_modules({
      go_error_collapse = {
        module_path = 'your-plugin',
        enable = config.options.enable,
        is_supported = function(lang)
          return vim.tbl_contains(config.options.languages, lang)
        end,
        attach = M.attach,
        detach = M.detach,
      }
    })
  end
end

function M.attach(bufnr, lang)
  if lang ~= "go" then
    return
  end

  local ns_id = config.ns
  local update = require('your-plugin.update')

  -- Initial display
  update.do_update(bufnr, ns_id)

  -- Set up incremental updates
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    buffer = bufnr,
    callback = function()
      update.throttled_update(bufnr, ns_id)
    end,
  })

  vim.api.nvim_create_autocmd('WinScrolled', {
    buffer = bufnr,
    callback = function()
      update.throttled_update(bufnr, ns_id)
    end,
  })
end

function M.detach(bufnr)
  local ns_id = vim.api.nvim_get_namespaces()['your-plugin']
  if ns_id then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

function M.toggle()
  config.options.enable = not config.options.enable

  if config.options.enable then
    M.enable_all_buffers()
  else
    M.disable_all_buffers()
  end
end

return M
```

## Key Principles

### Lazy Loading
1. **Minimal plugin/ entry**: Only VimL commands, no Lua execution
2. **Deferred initialization**: Use `vim.defer_fn()` for post-VimEnter setup
3. **On-demand module loading**: `require()` only when commands are used
4. **FileType autocmds**: Attach only to relevant buffers

### Performance
1. **Viewport limiting**: Only process visible lines
2. **Memoization**: Cache results by buffer tick
3. **Throttling**: Debounce updates with timers
4. **Incremental updates**: Track valid/invalid state
5. **Auto-cleanup**: Use `nvim_buf_attach` for resource management

### Architecture
1. **Module separation**: config, query, display, update as separate modules
2. **Namespace isolation**: Dedicated namespace for extmarks
3. **Event-driven**: Use autocmds and buffer attach, not polling
4. **Graceful degradation**: Check for TreeSitter availability

### TreeSitter Integration
1. **Custom queries**: Define in `queries/<lang>/<name>.scm`
2. **Query caching**: nvim-treesitter handles this automatically
3. **Tree traversal**: Use `parser:for_each_tree()` for multi-language files
4. **Node metadata**: Use capture metadata for query customization

## Common Patterns Reference

### Checking Buffer Validity
```lua
function M.is_valid_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local buftype = vim.bo[buf].buftype
  if buftype ~= "" then
    return false
  end

  local filetype = vim.bo[buf].filetype
  if not vim.tbl_contains(config.options.languages, filetype) then
    return false
  end

  return true
end
```

### Iterating Visible Windows
```lua
function M.update_all_visible()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if M.is_valid_buf(buf) then
        M.attach(buf)
      end
    end
  end
end
```

### Getting Parser Safely
```lua
function M.get_parser(bufnr, lang)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok then
    return nil
  end
  return parser
end
```

## Testing Queries

Test your TreeSitter queries with:
```lua
:lua vim.treesitter.query.edit()
```

Or programmatically:
```lua
local query_string = [[
  (if_statement) @test
]]

local query = vim.treesitter.query.parse("go", query_string)
for id, node in query:iter_captures(root, bufnr, 0, -1) do
  print(query.captures[id], node:type())
end
```

## User Configuration Example

Users configure your plugin like:
```lua
require('your-plugin').setup({
  enable = true,
  languages = { "go" },
  display = {
    icon = "⚠",
    style = "eol",
    throttle = 150,
  },
  patterns = {
    error_check = true,
    error_wrap = true,
  },
})
```

Or with nvim-treesitter:
```lua
require('nvim-treesitter.configs').setup({
  your_plugin = {
    enable = true,
    -- plugin-specific options
  }
})
```

## Complete Working Example: Go Error Collapse Plugin

See the patterns above combined into a complete, production-ready plugin architecture that:
- Lazy loads on FileType
- Uses TreeSitter queries for accurate detection
- Implements viewport-based rendering
- Throttles updates for performance
- Provides user configuration
- Integrates with nvim-treesitter module system
- Handles cleanup automatically

This architecture is battle-tested from nvim-treesitter (80k+ lines) and todo-comments.nvim (production plugin by folke).
