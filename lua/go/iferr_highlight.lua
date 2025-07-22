local M = {}

local query_string = [[
(if_statement
  condition: (binary_expression
    left: (identifier) @err_var (#eq? @err_var "err")
    operator: "!="
    right: (nil)
  )
  consequence: (block
    (return_statement
      (expression_list
        (identifier) @ret_err (#eq? @ret_err "err")
      )
    )
  )
) @iferr_block
]]

local query = nil
local augroup_id = nil
local namespace = vim.api.nvim_create_namespace('go_iferr_highlight')

local function highlight_buffer(bufnr)
  if not query then return end

  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  local parser = vim.treesitter.get_parser(bufnr, 'go')
  if not parser then return end

  local tree = parser:parse()[1]
  if not tree then return end

  for _, match in query:iter_matches(tree:root(), bufnr, 0, -1) do
    for _, nodes in pairs(match) do
      for _, node in ipairs(nodes) do
        local start_row, start_col, end_row, end_col = node:range()
        vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = 'Comment',
          priority = 128
        })
      end
    end
  end
end

local function clear_all_go_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == 'go' then
      vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end
  end
end

local function highlight_all_go_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == 'go' then
      highlight_buffer(bufnr)
    end
  end
end

function M.setup(config)
  if not config or not config.iferr_less_highlight then
    if augroup_id then
      vim.api.nvim_del_augroup_by_id(augroup_id)
      augroup_id = nil
    end
    clear_all_go_buffers()
    return
  end

  if not query then
    local ok, parsed_query = pcall(vim.treesitter.query.parse, 'go', query_string)
    if not ok then
      vim.notify('go.nvim: Failed to parse iferr highlight query', vim.log.levels.ERROR)
      return
    end
    query = parsed_query
  end

  if not augroup_id then
    augroup_id = vim.api.nvim_create_augroup('GoIfErrHighlight', { clear = true })
    
    vim.api.nvim_create_autocmd({'BufEnter', 'BufWritePost', 'TextChanged', 'InsertLeave'}, {
      group = augroup_id,
      pattern = '*.go',
      callback = function(event)
        if vim.bo[event.buf].filetype == 'go' then
          -- Delay to ensure treesitter has parsed the buffer
          vim.defer_fn(function() highlight_buffer(event.buf) end, 10)
        end
      end,
    })
  end

  highlight_all_go_buffers()
end

function M.toggle()
  if _GO_NVIM_CFG then
    _GO_NVIM_CFG.iferr_less_highlight = not _GO_NVIM_CFG.iferr_less_highlight
    M.setup(_GO_NVIM_CFG)
    vim.notify('If-err highlighting ' .. (_GO_NVIM_CFG.iferr_less_highlight and 'enabled' or 'disabled'))
  end
end

vim.api.nvim_create_user_command('GoToggleIferrLessHighlight', M.toggle, {
  desc = 'Toggle if-err less highlighting in Go files'
})

return M
