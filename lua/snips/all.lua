local ls = require("luasnip")
local utils = require("go.utils")
local partial = require("luasnip.extras").partial
local l = require("luasnip.extras").lambda
local dl = require("luasnip.extras").dynamic_lambda
local aws = vim.split(
  "ap-south-1,ap-northeast-2,ap-southeast-1,ap-southeast-2,ap-northeast-1,ca-central-1,eu-central-1,eu-west-1,eu-west-2,sa-east-1,us-east-1,us-east-2,us-west-1,us-west-2",
  ","
)
local function filter(prefix)
  local result = { ls.t("") }
  print("filter", prefix)
  if #prefix == 1 then
    for _, v in pairs(aws) do
      if v:sub(1, 1) == prefix then
        table.insert(result, ls.t(v))
      end
    end
    if #result > 0 then
      return ls.sn(nil, ls.c(1, result))
    end
  end
  if #prefix >= 2 then
    for _, v in pairs(aws) do
      if v:sub(1, 1) == prefix:sub(1, 1) then
        if v:sub(2, 2) == prefix:sub(2, 2) then
          table.insert(result, ls.t(v))
        else
          if v:find(prefix:sub(2, 2)) then
            print(v)
            table.insert(result, ls.t(v))
          end
        end
      end
    end
    if #result > 0 then
      print("prepare c node items ", #result)
      return ls.sn(nil, ls.c(1, result))
    end
  end
  return ls.sn(nil, ls.t("us-east-1"))
end

ls.add_snippets("all", {
  ls.s("time", partial(vim.fn.strftime, "%H:%M:%S")),
  ls.s("date", partial(vim.fn.strftime, "%Y-%m-%d")),
  ls.s("pwd", { partial(utils.run_command, "pwd") }),
  -- ls.s({ trig = "aws(%d)", regTrig = true, name = "aws region", dscr = "input 2 char matching a region name" }, {
  --   ls.d(1, function(args)
  --     print(vim.inspect(args))
  --     -- return ls.sn(nil, {
  --     --   -- jump-indices are local to each snippetNode, so restart at 1.
  --     --   ls.i(1, args[1]),
  --     -- })
  --     return filter(args[1][1])
  --   end, { 1 }),
  -- }),
  ls.s("hlc", ls.t("http://localhost")),
  ls.s("hl1", ls.t("http://127.0.0.1")),
  ls.s("lh", ls.t("localhost")),
  ls.s("lh1", ls.t("127.0.0.1")),
  ls.s({ trig = "uid", wordTrig = true }, { ls.f(utils.uuid), ls.i(0) }),
  ls.s({ trig = "rstr(%d+)", regTrig = true }, {
    ls.f(function(_, snip)
      return utils.random_string(snip.captures[1])
    end),
    ls.i(0),
  }),
  ls.s(
    { trig = "lor", name = "Lorem Ipsum (Choice)", dscr = "Choose next for more lines" },
    ls.c(1, { ls.t(utils.random_line()), ls.t(utils.random_line()) })
  ),
  ls.s(
    {
      trig = "lor(%d+)",
      name = "Lorem Ipsum",
      regTrig = true,
      dscr = "Start with a count for lines",
    },
    ls.f(function(_, snip)
      local lines = snip.captures[1]
      if not tonumber(lines) then
        lines = 1
      end
      local lor = vim.split(utils.lorem(), ", ")
      return vim.list_slice(lor, lines)
    end)
  ),
})
