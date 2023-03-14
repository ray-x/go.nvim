--https://github.com/mfrigerio17/lua-template-engine/

local function errHandler(e)
  -- Try to get the number of the line of the template that caused the error,
  -- parsing the text of the stacktrace. Note that the string here in the
  -- matching pattern should correspond to whatever is generated in the
  -- template_eval function, further down
  local stacktrace = debug.traceback()
  local linen = tonumber(stacktrace:match('.-"local text={}..."]:(%d+).*'))
  return {
    error = e,
    lineNum = linen,
  }
end

--- Evaluate a chunk of code in a constrained environment.
-- @param unsafe_code code string
-- @param optional environment table.
-- @return true or false depending on success
-- @return function or error message
local function eval_sandbox(unsafe_code, env)
  local env = env or {}
  local unsafe_fun, msg = load(unsafe_code, nil, 't', env)
  if unsafe_fun == nil then
    return false, { loadError = true, msg = msg }
  end
  return xpcall(unsafe_fun, errHandler)
end

local function lines(s)
  if s:sub(-1) ~= '\n' then
    s = s .. '\n'
  end
  return s:gmatch('(.-)\n')
end

--- Copy every string in the second argument into the first, prepending indentation.
-- The first argument must be a table. The second argument is either a table
-- itself (having strings as elements) or a function returning a factory of
-- a suitable iterator; for example, a function returning 'ipairs(t)', where 't'
-- is a table of strings, is a valid argument.
local insertLines = function(text, lines, totIndent)
  local factory = lines
  if type(lines) == 'table' then
    factory = function()
      return ipairs(lines)
    end
  end
  for i, line in factory() do
    local lineadd = ''
    if line ~= '' then
      lineadd = totIndent .. line
    end
    table.insert(text, lineadd)
  end
end

--- Decorates an existing string iteration, adding an optional prefix and suffix.
-- The first argument must be a function returning an existing iterator
-- generator, such as a 'ipairs'.
-- The second and last argument are strings, both optional.
--
-- Sample usage:
--   local t = {"a","b","c","d"}
--   for i,v in ipairs(t) do
--     print(i,v)
--   end
--
--   for i,v in lineDecorator( function() return ipairs(t) end, "--- ", " ###") do
--     print(i,v)
--   end
local lineDecorator = function(generator, prefix, suffix)
  local opts = opts or {}
  local prefix = prefix or ''
  local suffix = suffix or ''
  local iter, inv, ctrl = generator()

  return function()
    local i, line = iter(inv, ctrl)
    ctrl = i
    local retline = ''
    if line ~= nil then
      if line ~= '' then
        retline = prefix .. line .. suffix
      end
    end
    return i, retline -- nil or ""
  end
end

--- Evaluate the given text-template into a string.
-- Regular text in the template is copied verbatim, while expressions in the
-- form $(<var>) are replaced with the textual representation of <var>, which
-- must be defined in the given environment.
-- Finally, lines starting with @ are interpreted entirely as Lua code.
--
-- @param template the text-template, as a string
-- @param env the environment for the evaluation of the expressions in the
--        templates (if not given, 'table', 'pairs', 'ipairs' are added
--        automatically to this enviroment)
-- @param opts non-mandatory options
--        - indent: number of blanks to be prepended before every output line;
--          this applies to the whole template, relative indentation between
--          different lines is preserved
--        - xtendStyle: if true, variables are matched with this pattern "«<var>»"
-- @return The text of the evaluated template; if the option 'returnTable' is
--         set to true, though, the table with the sequence of lines of text is
--         returned instead
local function template_eval(template, env, opts)
  local opts = opts or {}
  local indent = string.format('%s', string.rep(' ', (opts.indent or 0)))

  -- Define the matching patter for the variables, depending on options.
  -- The matching pattern reads in general as: <text><var><string position>
  local varMatch = {
    pattern = '(.-)$(%b())()',
    extract = function(expr)
      return expr:sub(2, -2)
    end,
  }
  if opts.xtendStyle then
    varMatch.pattern = '(.-)«(.-)»()'
    varMatch.extract = function(expr)
      return expr
    end
  end

  -- Generate a line of code for each line in the input template.
  -- The lines of code are also strings; we add them in the 'chunk' table.
  -- Every line is either the insertion in a table of a string, or a 1-to-1 copy
  --  of the code inserted in the template via the '@' character.
  local chunk = { 'local text={}' }
  local lineOfCode = nil
  for line in lines(template) do
    -- Look for a '@' ignoring blanks (%s) at the beginning of the line
    -- If it's there, copy the string following the '@'
    local s, e = line:find('^%s*@')
    if s then
      lineOfCode = line:sub(e + 1)
    else
      -- Look for the specials '${..}', which must be alone in the line
      local tableIndent, tableVarName = line:match('^([%s]*)${(.-)}[%s]*')
      if tableVarName ~= nil then
        -- Preserve the indentation used for the "${..}" in the original template.
        -- "Sum" it to the global indentation passed here as an option.
        local totIndent = string.format('%q', indent .. tableIndent)
        lineOfCode = '__insertLines(text, ' .. tableVarName .. ', ' .. totIndent .. ')'
      else
        -- Look for the template variables in the current line.
        -- All the matches are stored as strings '"<text>" .. <variable>'
        -- Note that <text> can be empty
        local subexpr = {}
        local lastindex = 1
        local c = 1
        for text, expr, index in line:gmatch(varMatch.pattern) do
          subexpr[c] = string.format('%q .. %s', text, varMatch.extract(expr))
          lastindex = index
          c = c + 1
        end
        -- Add the remaining part of the line (no further variable) - or the
        -- entire line if no $() was found
        subexpr[c] = string.format('%q', line:sub(lastindex))

        -- Concatenate the subexpressions into a single one, prepending the
        -- indentation if it is not empty
        local expression = table.concat(subexpr, ' .. ')
        if expression ~= '""' and indent ~= '' then
          expression = string.format('%q', indent) .. ' .. ' .. expression
        end

        lineOfCode = 'table.insert(text, ' .. expression .. ')'
      end
    end
    table.insert(chunk, lineOfCode)
  end

  local returnTable = opts.returnTable or false
  if returnTable then
    table.insert(chunk, 'return text')
  else
    -- The last line of code performs string concatenation, so that the evaluation
    -- of the code eventually leads to a string
    table.insert(chunk, "return table.concat(text, '\\n')")
  end
  --print( table.concat(chunk, '\n') )

  env.table = (env.table or table)
  env.pairs = (env.pairs or pairs)
  env.ipairs = (env.ipairs or ipairs)
  env.__insertLines = insertLines
  local ok, ret = eval_sandbox(table.concat(chunk, '\n'), env)
  if not ok then
    local errMessage = 'Error in template evaluation' -- default, should be overwritten
    if ret.loadError then
      errMessage = 'Syntactic error in the loaded code: ' .. ret.msg
    else
      local linen = ret.lineNum or -1
      local line = '??'
      if linen ~= -1 then
        line = chunk[linen]
      end
      local err1 = 'Template evaluation failed around this line:\n\t>>> '
        .. line
        .. ' (line #'
        .. linen
        .. ')'
      local err2 = 'Interpreter error: ' .. (tostring(ret.error) or '')
      errMessage = err1 .. '\n' .. err2
    end
    return false, errMessage
  end
  return ok, ret
end

return {
  template_eval = template_eval,
  lineDecorator = lineDecorator,
}
