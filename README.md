# mybatis.nvim

Jump between MyBatis Java mapper interfaces and XML mapper files.

## Features

- From Java mapper method → jump to matching XML `<select|insert|update|delete ... id="...">`
- From XML `<... id="...">` → jump to matching Java mapper method
- From XML `<include refid="...">` → jump to local `<sql id="...">`
- From XML `resultMap="..."` (when cursor is on the attribute) → jump to local `<resultMap id="...">`
- From XML `resultType="..."` / `<resultMap type="...">` (cursor on the attribute) → jump to Java type
- Multiple matches open Quickfix

## Install

Example with `lazy.nvim`:

```lua
{
  "qumn/mybatis.nvim",
  cmd = { "MybatisJump" },
  opts = {
    mapper = {
      filename_patterns = { "Mapper%.java$", "Mapper%.xml$" },
    },
  },
}
```

## Usage

- Command: `:MybatisJump`
- Lua: `require("mybatis").jump()` / `require("mybatis").jump_or_fallback()`

## Recommended keymap (no defaults)

This plugin does not create a `gd` mapping by default. Recommended (buffer-local) setup:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "java", "xml" },
  callback = function(args)
    local mybatis = require("mybatis")
    if not mybatis.is_mapper_file(args.buf) then
      return
    end

    vim.keymap.set("n", "gd", function()
      mybatis.jump_or_fallback()
    end, { buffer = args.buf, desc = "MyBatis jump or definition" })
  end,
})
```

## Telescope integration (for `gd` → `telescope.builtin.lsp_definitions`)

If you map `gd` to Telescope definitions, you can wrap it to be MyBatis-aware:

```lua
{
  "nvim-telescope/telescope.nvim",
  opts = function(_, opts)
    local builtin = require("telescope.builtin")
    local orig = builtin.lsp_definitions

    builtin.lsp_definitions = function(o)
      local mybatis = require("mybatis")
      if mybatis.is_mapper_file(0) then
        return mybatis.jump_or_fallback()
      end
      return orig(o)
    end

    return opts
  end,
}
```

## Configuration

```lua
require("mybatis").setup({
  root_markers = { ".git", "pom.xml", "build.gradle", "settings.gradle" }, -- project root markers for searching
  mapper_tags = { "select", "insert", "update", "delete", "sql", "resultMap" }, -- XML tags treated as mapping definitions
  mapper = {
    filetypes = { "java", "xml" }, -- filetypes eligible for MyBatis jump logic
    filename_patterns = { "Mapper%.java$", "Mapper%.xml$" }, -- Lua patterns; empty = no filename filtering
  },
  fallback = {
    prefer_lsp = true, -- if no MyBatis target found, prefer `vim.lsp.buf.definition()` when available
  },
})
```
