-- https://github.com/arsham/shark/blob/master/lua/settings/luasnip/go.lua
local ls = require("luasnip")
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep
local ai = require("luasnip.nodes.absolute_indexer")
local partial = require("luasnip.extras").partial
local snips = require("go.snips")
local log = require("go.utils").log
local in_test_fn = {
  show_condition = snips.in_test_function,
  condition = snips.in_test_function,
}

local in_test_file = {
  show_condition = snips.in_test_file_fn,
  condition = snips.in_test_file_fn,
}

local in_fn = {
  show_condition = snips.in_function,
  condition = snips.in_function,
}

local not_in_fn = {
  show_condition = snips.in_func,
  condition = snips.in_func,
}

-- stylua: ignore start
local snippets = {
  -- Main
  ls.s(
    { trig = "main", name = "Main", dscr = "Create a main function" },
    fmta("func main() {\n\t<>\n}", ls.i(0)),
    not_in_fn
  ),

  -- If call error
  ls.s(
    { trig = "ifc", name = "if call", dscr = "Call a function and check the error" },
    fmt(
      [[
        {val}, {err1} := {func}({args})
        if {err2} != nil {{
          return {err3}
        }}
        {finally}
      ]], {
        val     = ls.i(1, { "val" }),
        err1    = ls.i(2, { "err" }),
        func    = ls.i(3, { "func" }),
        args    = ls.i(4),
        err2    = rep(2),
        err3    = ls.d(5, snips.make_return_nodes, { 2 }),
        finally = ls.i(0),
    }),
    snips.in_fn
  ),

  -- if err:=call(); err != nil { return err }
  ls.s(
    { trig = "ifce", name = "if call err inline", dscr = "Call a function and check the error inline" },
    fmt(
      [[
        if {err1} := {func}({args}); {err2} != nil {{
          return {err3}
        }}
        {finally}
      ]], {
        err1    = ls.i(1, { "err" }),
        func    = ls.i(2, { "func" }),
        args    = ls.i(3, { "args" }),
        err2    = rep(1),
        err3    = ls.d(4, snips.make_return_nodes, { 1 }),
        finally = ls.i(0),
    }),
    snips.in_fn
  ),

  -- Function
  ls.s(
    { trig = "fn", name = "Function", dscr = "Create a function or a method" },
    fmt(
      [[
        // {name1} {desc}
        func {rec}{name2}({args}) {ret} {{
          {finally}
        }}
      ]], {
        name1 = rep(2),
        desc  = ls.i(5, "description"),
        rec   = ls.c(1, {
          ls.t(""),
          ls.sn(nil, fmt("({} {}) ", {
            ls.i(1, "r"),
            ls.i(2, "receiver"),
          })),
        }),
        name2 = ls.i(2, "Name"),
        args  = ls.i(3),
        ret   = ls.c(4, {
          ls.i(1, "error"),
          ls.sn(nil, fmt("({}, {}) ", {
            ls.i(1, "ret"),
            ls.i(2, "error"),
          })),
        }),
        finally = ls.i(0),
    }),
    not_in_fn
  ),

  -- If error
  ls.s(
    { trig = "ife", name = "If error", dscr = "If error, return wrapped" },
    fmt("if {} != nil {{\n\treturn {}\n}}\n{}", {
      ls.i(1, "err"),
      ls.d(2, snips.make_return_nodes, { 1 }, { user_args = { { "a1", "a2" } } }),
      ls.i(0),
    }),
    in_fn
  ),

  -- errors.Wrap
  ls.s(
    { trig = "erw", dscr = "errors.Wrap" },
    fmt([[errors.Wrap({}, "{}")]], {
      ls.i(1, "err"),
      ls.i(2, "failed to"),
    })
  ),

  -- errors.Wrapf
  ls.s(
    { trig = "erwf", dscr = "errors.Wrapf" },
    fmt([[errors.Wrapf({}, "{}", {})]], {
      ls.i(1, "err"),
      ls.i(2, "failed %v"),
      ls.i(3, "args"),
    })
  ),

  -- for select
  ls.s(
    { trig = "fsel", dscr = "for select" },
    fmt([[
for {{
	  select {{
        case {} <- {}:
			      {}
        default:
            {}
	  }}
}}
]], {
      ls.i(1, {ls.i(1, "ch"), ls.i(2, "ch := ")}),
      ls.i(2, "ch"),
      ls.i(3, "break"),
      ls.i(0, ""),
    })
  ),
  -- type switch
  ls.s(
    { trig = "tysw", dscr = "type switch" },
    fmt([[
switch {} := {}.(type) {{
    case {}:
        {}
    default:
        {}
}}
]], {
      ls.i(1, "v"),
      ls.i(2, "i"),
      ls.i(3, "int"),
      ls.i(4, 'fmt.Println("int")'),
      ls.i(0, ""),
    })
  ),
  -- fmt.Sprintf
  ls.s(
    { trig = "spn", dscr = "fmt.Sprintf" },
    fmt([[fmt.Sprintf("{}%{}", {})]], {
      ls.i(1, "msg "),
      ls.i(2, "+v"),
      ls.i(2, "arg"),
    })
  ),

  -- build tags
  ls.s(
    { trig = "//tag", dscr = "// +build tags" },
    fmt([[// +build:{}{}]], {
      ls.i(1, "integration"),
      ls.i(2, ",unit"),
    })
  ),

  -- Nolint
  ls.s(
    { trig = "nolt", dscr = "ignore linter" },
    fmt([[// nolint:{}{}]], {
      ls.i(1, "funlen"),
      ls.i(2, ",cyclop"),
    })
  ),

  -- defer recover
  ls.s(
    { trig = "dfr", dscr = "defer recover" },
    fmt(
      [[
        defer func() {{
            if err := recover(); err != nil {{
       	        {}
            }}
        }}()]], {
      ls.i(1, ""),
    })
  ),

  -- Allocate Slices and Maps
  ls.s(
    { trig = "make", name = "Make", dscr = "Allocate map or slice" },
    fmt("{} {}= make({})\n{}", {
      ls.i(1, "name"),
      ls.i(2),
      ls.c(3, {
        fmt("[]{}, {}", { ls.r(1, "type"), ls.i(2, "len") }),
        fmt("[]{}, 0, {}", { ls.r(1, "type"), ls.i(2, "len") }),
        fmt("map[{}]{}, {}", { ls.r(1, "type"), ls.i(2, "values"), ls.i(3, "len") }),
      }, {
        stored = { -- FIXME: the default value is not set.
          type = ls.i(1, "type"),
        },
      }),
      ls.i(0),
    }),
    in_fn
  ),

  -- Test Cases
  ls.s(
    { trig = "tcs", dscr = "create test cases for testing" },
    fmta(
      [[
        tcs := map[string]struct {
        	<>
        } {
        	// Test cases here
        }
        for name, tc := range tcs {
        	tc := tc
        	t.Run(name, func(t *testing.T) {
        		<>
        	})
        }
      ]],
      { ls.i(1), ls.i(2) }
    ),
    in_test_fn
  ),

  -- Create Mocks
  ls.s(
    { trig = "mock", name = "Mocks", dscr = "Create a mock with defering assertion" },
    fmt("{} := &mocks.{}{{}}\ndefer {}.AssertExpectations(t)\n{}", {
      ls.i(1, "m"),
      ls.i(2, "Mocked"),
      rep(1),
      ls.i(0),
    }),
    in_test_fn
  ),

  -- Require NoError
  ls.s(
    { trig = "noerr", name = "Require No Error", dscr = "Add a require.NoError call" },
    ls.c(1, {
      ls.sn(nil, fmt("require.NoError(t, {})", { ls.i(1, "err") })),
      ls.sn(nil, fmt('require.NoError(t, {}, "{}")', { ls.i(1, "err"), ls.i(2) })),
      ls.sn(nil, fmt('require.NoErrorf(t, {}, "{}", {})', { ls.i(1, "err"), ls.i(2), ls.i(3) })),
    }),
    in_test_fn
  ),

  -- Assert equal
  ls.s(
    { trig = "aeq", name = "Assert Equal", dscr = "Add assert.Equal" },
    ls.c(1, {
      ls.sn(nil, fmt('assert.Equal(t, {}, {})', { ls.i(1, "got"), ls.i(2, "want") })),
      ls.sn(nil, fmt('assert.Equalf(t, {}, {}, "{}", {})', { ls.i(1, "got"), ls.i(2, "want"), ls.i(3, "got %v not equal to want"), ls.i(4, "got") })),
    }),
    in_test_fn
  ),
  -- Subtests
  ls.s(
    { trig = "Test", name = "Test/Subtest", dscr = "Create subtests and their function stubs" },
    fmta("func <>(t *testing.T) {\n<>\n}\n\n <>", {
      ls.i(1),
      ls.d(2, snips.create_t_run, ai({ 1 })),
      ls.d(3, snips.mirror_t_run_funcs, ai({ 2 })),
    }),
    in_test_file
  ),

  -- Stringer
  ls.s(
    { trig = "strigner", name = "Stringer", dscr = "Create a stringer go:generate" },
    fmt("//go:generate stringer -type={} -output={}_string.go", {
      ls.i(1, "Type"),
      partial(vim.fn.expand, "%:t:r"),
    })
  ),
}

log('create snippet')

ls.add_snippets("go", snippets)
-- stylua: ignore end
