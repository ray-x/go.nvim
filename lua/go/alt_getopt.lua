-- Copyright (c) 2009 Aleksey Cheusov <vle@gmx.net>
-- Copyright info:
-- https://github.com/cheusov/lua-alt-getopt/blob/f495c21d6a203ab280603aa5799e636fb5651ae7/alt_getopt.lua#L3-L20

-- updated for neovim lua JIT by ray-x

local type, pairs, ipairs, os = type, pairs, ipairs, os

local alt_getopt = {}

local function convert_short2long(opts)
  local ret = {}

  for short_opt, accept_arg in opts:gmatch("(%w)(:?)") do
    ret[short_opt] = #accept_arg
  end

  return ret
end

local function err_unknown_opt(opt)
  -- vim.notify("Unknown option `-" .. (#opt > 1 and "-" or "") .. opt, vim.lsp.log_levels.INFO)
end

local function canonize(options, opt)
  if not options[opt] then
    err_unknown_opt(opt)
  end

  while type(options[opt]) == "string" do
    opt = options[opt]

    if not options[opt] then
      err_unknown_opt(opt)
    end
  end

  return opt
end

function alt_getopt.get_ordered_opts(arg, sh_opts, long_opts)
  local i = 1
  local count = 1
  local opts = {}
  local optarg = {}

  local options = convert_short2long(sh_opts)
  for k, v in pairs(long_opts) do
    options[k] = v
  end

  local unparsed = {}

  while i <= #arg do
    local a = arg[i]
    if a == "--" then
      i = i + 1
      break
    elseif a == "-" then
      break
    elseif a:sub(1, 2) == "--" then
      local pos = a:find("=", 1, true)

      if pos then
        local opt = a:sub(3, pos - 1)

        opt = canonize(options, opt)

        if options[opt] == 0 then
          vim.notify("Bad usage of option `" .. a, vim.lsp.log_levels.ERROR)
        end

        optarg[count] = a:sub(pos + 1)
        opts[count] = opt
      else
        local opt = a:sub(3)

        opt = canonize(options, opt)

        if options[opt] == 0 then
          opts[count] = opt
        else
          if i == #arg then
            vim.notify("Missed value for option `" .. a, vim.lsp.log_levels.ERROR)
            return
          end

          optarg[count] = arg[i + 1]
          opts[count] = opt
          i = i + 1
        end
      end
      count = count + 1
    elseif a:sub(1, 1) == "-" then
      for j = 2, a:len() do
        local opt = canonize(options, a:sub(j, j))

        if options[opt] == 0 then
          opts[count] = opt
          count = count + 1
        elseif a:len() == j then
          if i == #arg then
            vim.notify("Missed value for option `-" .. opt, vim.lsp.log_levels.ERROR)
          end

          optarg[count] = arg[i + 1]
          opts[count] = opt
          i = i + 1
          count = count + 1
          break
        else
          optarg[count] = a:sub(j + 1)
          opts[count] = opt
          count = count + 1
          break
        end
      end
    else
      table.insert(unparsed, a)
    end

    i = i + 1
  end

  return opts, i, optarg, unparsed
end

function alt_getopt.get_opts(arg, sh_opts, long_opts)
  local ret = {}

  local opts, optind, optarg, unparsed = alt_getopt.get_ordered_opts(arg, sh_opts, long_opts)
  for i, v in ipairs(opts) do
    if optarg[i] then
      ret[v] = optarg[i]
    else
      ret[v] = 1
    end
  end

  return ret, optind, unparsed
end

function test_arg(arg)
  local long_opts = {
    verbose = "v",
    help = "h",
    test = "t",
    stop = "s",
    restart = "r",
    -- fake = 0,
    -- len = 1,
    tags = "g",
    output = "o",
    set_value = "S",
    ["set-output"] = "o",
  }

  local opts
  local optarg
  local optind
  arg = arg or { "-t", "-r", "-c", "path1", "-g", "unit,integration", "path" }
  opts, optind, optarg, unparsed = alt_getopt.get_ordered_opts(arg, "cg:hvo:n:rS:st", long_opts)

  print("ordered opts")
  print(vim.inspect(opts))
  print(vim.inspect(optind))
  print(vim.inspect(optarg))
  print(vim.inspect(unparsed))
  print("ordered opts end")
  for i, v in ipairs(opts) do
    if optarg[i] then
      print("option opts[i] " .. v .. ": " .. vim.inspect(optarg[i]))
    else
      print("option " .. v)
    end
  end

  print("get_opts ")
  optarg, optind, unparsed = alt_getopt.get_opts(arg, "cg:hVvo:n:rS:st", long_opts)
  print("opts " .. vim.inspect(optarg))
  print("optind " .. vim.inspect(optind))
  print(vim.inspect(unparsed))
  local fin_options = {}
  for k, v in pairs(optarg) do
    table.insert(fin_options, "fin-option " .. k .. ": " .. vim.inspect(v) .. "\n")
  end
  table.sort(fin_options)

  print(table.concat(fin_options))
  --
  for i = optind, #arg do
    print(string.format("ARGV [%s] = %s\n", i, arg[i]))
  end
end

-- test_arg()
--
-- print("test 2")
--
-- test_arg({ "-tr", "-c", "-g", "unit,integration" })
-- test_arg({ "--tags", "unit,integration", "--restart" })
-- test_arg({ "run", "restart" })
-- test_arg({ "--tags", "unit,integration", "-c", "--restart" })

return alt_getopt
