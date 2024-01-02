-- golines A golang formatter that fixes long lines
-- golines + goimport
local api = vim.api
local utils = require('go.utils')
local log = utils.log
local max_len = _GO_NVIM_CFG.max_line_len or 120
local gofmt = _GO_NVIM_CFG.gofmt or 'gofumpt'
local vfn = vim.fn
local write_delay = 10
if _GO_NVIM_CFG.lsp_fmt_async then
    write_delay = 200
end

local install = require('go.install').install
local gofmt_args = _GO_NVIM_CFG.gofmt_args
    or {
        '--max-len=' .. tostring(max_len),
        '--base-formatter=' .. gofmt,
    }

local goimport_args = _GO_NVIM_CFG.goimport_args
    or {
        '--max-len=' .. tostring(max_len),
        '--base-formatter=goimports',
    }

if vim.lsp.buf.format == nil then
    -- vim.notify('the vim.lsp.buf.format is not available, some feature is missing if you are running old version of neovim (<0.8.0)', vim.log.levels.DEBUG)
    -- neovim < 0.7 only
    require('go.lsp') -- this set default value of format
end

local run = function(fmtargs, bufnr, cmd)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    log(fmtargs, bufnr, cmd)
    if vim.o.mod == true then
        vim.cmd('noautocmd silent write')
    end
    if cmd == 'gopls' then
        if not vim.api.nvim_buf_is_loaded(bufnr) then
            vfn.bufload(bufnr)
        end
        -- log gopls format
        vim.lsp.buf.format({
            async = _GO_NVIM_CFG.lsp_fmt_async,
            bufnr = bufnr,
            name = 'gopls',
        })
        if not _GO_NVIM_CFG.lsp_fmt_async then
            vim.defer_fn(function()
                if vfn.getbufinfo('%')[1].changed == 1 then
                    vim.cmd('noautocmd silent write')
                end
            end, write_delay)
        end
    end

    local args = vim.deepcopy(fmtargs)
    table.insert(args, api.nvim_buf_get_name(bufnr))
    log('formatting buffer... ' .. vim.inspect(args), vim.log.levels.DEBUG)

    local old_lines = api.nvim_buf_get_lines(0, 0, -1, true)
    if cmd then
        table.insert(args, 1, cmd)
    else
        table.insert(args, 1, 'golines')
    end
    log('fmt cmd:', args)

    local j = vfn.jobstart(args, {
        on_stdout = function(_, data, _)
            data = utils.handle_job_data(data)
            if not data then
                return
            end
            if not utils.check_same(old_lines, data) then
                vim.notify('updating codes', vim.log.levels.DEBUG)
                api.nvim_buf_set_lines(0, 0, -1, false, data)
                vim.cmd('silent write')
            else
                vim.notify('already formatted', vim.log.levels.INFO)
            end
            -- log("stdout" .. vim.inspect(data))
            old_lines = nil
        end,
        on_stderr = function(_, data, _)
            data = utils.handle_job_data(data)
            if data then
                log(vim.inspect(data) .. ' from stderr')
            end
        end,
        on_exit = function(_, data, _) -- id, data, event
            -- log(vim.inspect(data) .. "exit")
            if data ~= 0 then
                return vim.notify('golines failed ' .. tostring(data), vim.log.levels.ERROR)
            end
            old_lines = nil
            vim.defer_fn(function()
                if vfn.getbufinfo('%')[1].changed == 1 then
                    vim.cmd('noautocmd silent write')
                end
            end, 200)
        end,
        stdout_buffered = true,
        stderr_buffered = true,
    })
    vfn.chansend(j, old_lines)
    vfn.chanclose(j, 'stdin')
end

local M = {}
M.gofmt = function(...)
    local long_opts = {
        all = 'a',
    }

    local short_opts = 'a'
    local args = ... or {}

    local getopt = require('go.alt_getopt')
    local optarg = getopt.get_opts(args, short_opts, long_opts)
    log(optarg)

    local all_buf = false
    if optarg['a'] then
        all_buf = true
    end
    if not install(gofmt) then
        utils.warn('installing ' .. gofmt .. ' please retry after installation')
        return
    end
    if not install('golines') then
        utils.warn('installing golines , please rerun format after install finished')
        return
    end
    local a = {}
    utils.copy_array(gofmt_args, a)
    local fmtcmd
    if gofmt == 'gopls' then
        fmtcmd = 'gopls'
    end
    if all_buf then
        log('fmt all buffers')
        vim.cmd('wall')
        local bufs = utils.get_active_buf()
        log(bufs)

        for _, b in ipairs(bufs) do
            log(a, b)
            run(a, b.bufnr, fmtcmd)
        end
    else
        run(a, 0, fmtcmd)
    end
end

M.org_imports = function()
    require('go.lsp').codeaction('', 'source.organizeImports', function()
        vim.lsp.buf.format({
            async = _GO_NVIM_CFG.lsp_fmt_async,
            bufnr = vim.api.nvim_get_current_buf(),
            name = 'gopls',
        })
        if not _GO_NVIM_CFG.lsp_fmt_async then
            vim.defer_fn(function()
                if vfn.getbufinfo('%')[1].changed == 1 then
                    vim.cmd('noautocmd silent write')
                end
            end, write_delay)
        end
    end)
end

M.goimport = function(...)
    local goimport = _GO_NVIM_CFG.goimport or 'gopls'
    local args = { ... }
    log(args, goimport)
    if goimport == 'gopls' then
        if vfn.empty(args) == 1 then
            return M.org_imports()
        else
            local path = select(1, ...)
            local gopls = require('go.gopls')
            return gopls.import(path)
        end
    end
    local buf = vim.api.nvim_get_current_buf()
    require('go.install').install(goimport)
    -- specified the pkg name
    if #args > 0 then -- dont use golines
        return run(args, buf, 'goimports')
    end

    -- golines base formatter is goimports
    local a = {}
    if goimport == 'golines' then
        a = vim.deepcopy(goimport_args)
    end
    run(a, buf, goimport)
end

return M
