-- nvim --headless --noplugin -u lua/tests/minimal.vim -c "PlenaryBustedDirectory lua/tests/go_buildtargets_spec.lua {minimal_init = 'lua/tests/minimal.vim'}"
local eq = assert.are.same
-- local cur_dir = vim.fn.expand('%:p:h')
local busted = require('plenary/busted')

local menu = 'menu'
local items = 'items'

-- local template = {
--   -- ["/Users/kkrime/go/src/prj"] = {
--   asset_generator = { 4, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
--   error_creator = { 5, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
--   menu = {
--     height = 5,
--     items = { "protoc-gen-authoption", "protoc-gen-prj", "prj", "asset_generator", "error_creator" },
--     width = 21
--   },
--   ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--   ["protoc-gen-prj"] = { 2, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
--   prj = { 3, "/Users/kkrime/go/src/prj/main.go" }
--   -- }
-- }

-- describe('BuildTarget Refresh:', function()
--   local refresh_func = require('go.buildtargets')._refresh_project_buildtargerts

--   it("no change between original and refresh", function()
--     local original = vim.deepcopy(template)
--     local refresh = vim.deepcopy(template)
--     local expected_result = vim.deepcopy(template)

--     refresh_func(original, refresh)

--     eq(refresh, expected_result)
--   end)

--   it("test case 1", function()
--     local original = vim.deepcopy(template)
--     local refresh = {
--       asset_generator = { 3, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
--       error_creator = { 1, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
--       menu = {
--         height = 5,
--         items = { "error_creator", "prj", "asset_generator", "protoc-gen-prj", "protoc-gen-authoption" },
--         width = 21
--       },
--       ["protoc-gen-authoption"] = { 5, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--       ["protoc-gen-prj"] = { 4, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
--       prj = { 2, "/Users/kkrime/go/src/prj/main.go" }
--     }
--     local expected_result = vim.deepcopy(original)

--     refresh_func(original, refresh)

--     eq(refresh, expected_result)
--   end)

--   it("test case 2", function()
--     local original = {
--       error_creator = { 1, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
--       menu = {
--         height = 2,
--         items = { "error_creator", "prj" },
--         width = 13
--       },
--       prj = { 2, "/Users/kkrime/go/src/prj/main.go" }
--     }
--     local refresh = vim.deepcopy(template)

--     refresh_func(original, refresh)

--     local target = 'error_creator'
--     local first_target = refresh[target]
--     eq(first_target, { 1, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" })
--     eq(refresh[menu][items][1], target)
--     refresh[target] = nil

--     target = 'prj'
--     local second_target = refresh[target]
--     eq(second_target, { 2, "/Users/kkrime/go/src/prj/main.go" })
--     eq(refresh[menu][items][2], target)
--     refresh[target] = nil

--     eq(#refresh[menu][items], 5)
--     eq(refresh[menu]['width'], 21)

--     local items = refresh[menu][items]
--     refresh[menu] = nil

--     for i = 3, #items do
--       target = items[i]
--       assert(refresh[target] ~= nil, target .. " should be in refresh")
--       eq(refresh[target][1], i)
--       refresh[target] = nil
--     end

--     eq(refresh, {})
--   end)

--   it("test case 3", function()
--     local original = {
--       menu = {
--         height = 3,
--         items = { "protoc-gen-authoption", "protoc-gen-prj", "prj" },
--         width = 21
--       },
--       ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--       ["protoc-gen-prj"] = { 2, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
--       prj = { 3, "/Users/kkrime/go/src/prj/main.go" }
--     }
--     local refresh = {
--       menu = {
--         height = 2,
--         items = { "protoc-gen-authoption", "prj" },
--         width = 21
--       },
--       ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--       prj = { 2, "/Users/kkrime/go/src/prj/main.go" }
--     }
--     local expected_result = vim.deepcopy(refresh)

--     refresh_func(original, refresh)
--     eq(refresh, expected_result)
--   end)

--   it("test case 4", function()
--     local original = {
--       menu = {
--         height = 3,
--         items = { "protoc-gen-authoption", "protoc-gen-prj", "prj" },
--         width = 21
--       },
--       ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--       ["protoc-gen-prj"] = { 2, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
--       prj = { 3, "/Users/kkrime/go/src/prj/main.go" }
--     }
--     local refresh = {
--       menu = {
--         height = 2,
--         items = { "prj", "protoc-gen-authoption" },
--         width = 21
--       },
--       ["protoc-gen-authoption"] = { 2, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--       prj = { 1, "/Users/kkrime/go/src/prj/main.go" }
--     }
--     local expected_result = {
--       menu = {
--         height = 2,
--         items = { "protoc-gen-authoption", "prj" },
--         width = 21
--       },
--       ["protoc-gen-authoption"] = { 1, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
--       prj = { 2, "/Users/kkrime/go/src/prj/main.go" }
--     }

--     refresh_func(original, refresh)

--     eq(refresh, expected_result)
--   end)
-- end)
--
local template = {
  ["/Users/kkrime/go/src/prj"] = {
    asset_generator = { 3, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
    error_creator = { 1, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
    menu = {
      height = 5,
      items = { "error_creator", "prj", "asset_generator", "protoc-gen-authoption", "protoc-gen-prj" },
      width = 21
    },
    ["protoc-gen-authoption"] = { 4, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
    ["protoc-gen-prj"] = { 5, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
    prj = { 2, "/Users/kkrime/go/src/prj/main.go" }
  }
}

describe('Resolve Collisions:', function()
  it("test case 1", function()
    local buildtargets = require('go.buildtargets')
    local add_target_to_cache = buildtargets._add_target_to_cache
    local collisions = buildtargets._collisions

    local project_root = "/Users/kkrime/go/src/prj"
    local template = {
      [project_root] = {
        asset_generator = { 3, "/Users/kkrime/go/src/prj/internal/api/assets/generator/asset_generator.go" },
        error_creator = { 1, "/Users/kkrime/go/src/prj/internal/zerrors/generate/error_creator.go" },
        menu = {
          height = 5,
          items = { "error_creator", "prj", "asset_generator", "protoc-gen-authoption", "protoc-gen-prj" },
          width = 21
        },
        ["protoc-gen-authoption"] = { 4, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-authoption/main.go" },
        ["protoc-gen-prj"] = { 5, "/Users/kkrime/go/src/prj/internal/protoc/protoc-gen-prj/main.go" },
        prj = { 2, "/Users/kkrime/go/src/prj/main.go" }
      }
    }

    -- buildtargets._cache = template
    buildtargets._set_cache(template)

    local error_creator = { 6, "/Users/kkrime/go/src/prj/internal/error_creator.go" }

    add_target_to_cache('error_creator', error_creator, project_root)
    error_creator = { 7, "/Users/kkrime/go/src/prj/internal/protoc/internal/error_creator/main.go" }
    add_target_to_cache('error_creator', error_creator, project_root)
  end)
end)
