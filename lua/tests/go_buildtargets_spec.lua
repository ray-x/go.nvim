-- nvim --headless --noplugin -u lua/tests/minimal.vim -c "PlenaryBustedDirectory lua/tests/go_buildtargets_spec.lua {minimal_init = 'lua/tests/minimal.vim'}"
local eq = assert.are.same
-- local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

local menu = 'menu'
local items = 'items'

local origin = {
  ["/Users/kkrime/go/src/prj"] = {
    asset_generator = { 4, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
    error_creator = { 5, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
    menu = {
      height = 5,
      items = { "protoc-gen-authoption", "protoc-gen-prj", "prj", "asset_generator", "error_creator" },
      width = 21
    },
    ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
    ["protoc-gen-prj"] = { 2, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
    prj = { 3, "/Users/kkrime/go/src/prj/main.go" }
  }
}

-- local origin = {
--   ["/Users/kkrime/go/src/prj"] = {
--     ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--     ["protoc-gen-prj"] = { 2, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
--     prj = { 3, "/Users/kkrime/go/src/prj/main.go" }
--     asset_generator = { 4, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
--     error_creator = { 5, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
--   }
-- }

describe('BuildTarget Refresh:', function()
  local refresh_func = require('go.buildtargets')._refresh_project_buildtargerts

  it("no change between original and refresh", function()
    local original = vim.deepcopy(origin)
    local refresh = vim.deepcopy(origin)

    refresh_func(original["/Users/kkrime/go/src/prj"], refresh["/Users/kkrime/go/src/prj"])
  end
  )

  it("refresh contains new buildtarget", function()
    local original = vim.deepcopy(origin)
    original["/Users/kkrime/go/src/prj"]["error_creator"] = nil
    original["/Users/kkrime/go/src/prj"][menu][items] = { "protoc-gen-authoption", "protoc-gen-prj", "prj",
      "asset_generator" }
    original["/Users/kkrime/go/src/prj"][menu]['height'] = 4
    local refresh = vim.deepcopy(origin)

    refresh_func(original["/Users/kkrime/go/src/prj"], refresh["/Users/kkrime/go/src/prj"])
    eq(original, refresh)
  end
  )

  -- it("refresh contains multiple new buildtarget", function()
  --   local original = {
  --     ["/Users/kkrime/go/src/prj"] = {
  --       asset_generator = { 2, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
  --       menu = {
  --         height = 2,
  --         items = { "protoc-gen-prj", "asset_generator" },
  --         width = 15
  --       },
  --       ["protoc-gen-prj"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
  --     }
  --   }
  --   local refresh = vim.deepcopy(origin)
  --   local result = {
  --     ["/Users/kkrime/go/src/prj"] = {
  --       asset_generator = { 2, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
  --       error_creator = { 3, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
  --       menu = {
  --         height = 5,
  --         items = { "protoc-gen-prj", "asset_generator", "error_creator", "protoc-gen-authoption", "prj" },
  --         width = 21
  --       },
  --       prj = { 5, "/Users/kkrime/go/src/prj/main.go" },
  --       ["protoc-gen-authoption"] = { 4, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
  --       ["protoc-gen-prj"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" }
  --     }
  --   }
  --   refresh_func(original["/Users/kkrime/go/src/prj"], refresh["/Users/kkrime/go/src/prj"])
  --   eq(original, result)
  -- end
  -- )

  it("original contains buildtarget not in refresh", function()
    local original = vim.deepcopy(origin)
    local refresh = {
      ["/Users/kkrime/go/src/prj"] = {
        asset_generator = { 3, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
        error_creator = { 4, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
        menu = {
          height = 4,
          items = { "protoc-gen-authoption", "protoc-gen-prj", "asset_generator", "error_creator" },
          width = 21
        },
        ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
        ["protoc-gen-prj"] = { 2, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
      }
    }
    refresh_func(original["/Users/kkrime/go/src/prj"], refresh["/Users/kkrime/go/src/prj"])
    eq(original, refresh)
  end
  )

  it("original contains multiple buildtarget not in refresh", function()
    local original = vim.deepcopy(origin)
    local refresh = {
      ["/Users/kkrime/go/src/prj"] = {
        asset_generator = { 2, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
        menu = {
          height = 2,
          items = { "protoc-gen-prj", "asset_generator" },
          width = 15
        },
        ["protoc-gen-prj"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
      }
    }
    refresh_func(original["/Users/kkrime/go/src/prj"], refresh["/Users/kkrime/go/src/prj"])
    eq(original, refresh)
  end
  )
end)
