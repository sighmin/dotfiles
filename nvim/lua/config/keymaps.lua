-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Cycle the bufferline (the buffers shown tab-style at the top of nvim) with
-- vim's classic `gt`/`gT` keys. Native vim `gt` is `:tabnext` for tab *pages*,
-- which we don't use — LazyVim's bufferline is what visually looks like tabs.
-- Real tab-page ops are still available under <leader><tab>] / <leader><tab>[
-- if ever needed. <S-h>/<S-l> also still work (LazyVim's default).
vim.keymap.set("n", "gt", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer (bufferline)" })
vim.keymap.set("n", "gT", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer (bufferline)" })

-- Smart quit family: with bufferline showing multiple buffers as "tabs",
-- plain `:q` / `:wq` / `:quit` would close the window (= exit nvim, since
-- there's only one window). That mismatches the muscle memory from vim tab
-- pages where these commands closed *the tab*.
--
-- We wrap each: if multiple listed buffers exist, close just the current
-- buffer (window stays, shows the next buffer); otherwise fall through to
-- the native command. Snacks.bufdelete handles window layout better than
-- raw :bd (won't collapse splits when closing a buffer).
--
-- `:qa` / `:qa!` are deliberately NOT wrapped — they remain the escape hatch
-- for actually exiting nvim regardless of how many buffers are open.
local function has_multiple_buffers()
  return #vim.fn.getbufinfo({ buflisted = 1 }) > 1
end

-- :q and :q! — bang is forwarded so :q! force-closes (discards modifications).
vim.api.nvim_create_user_command("Q", function(opts)
  if has_multiple_buffers() then
    Snacks.bufdelete({ force = opts.bang })
  else
    vim.cmd(opts.bang and "quit!" or "quit")
  end
end, { bang = true, desc = "Close buffer if multiple, else quit" })

-- :wq and :wq! — writes the current buffer first, then closes it (or quits).
vim.api.nvim_create_user_command("Wq", function(opts)
  if has_multiple_buffers() then
    vim.cmd(opts.bang and "write!" or "write")
    Snacks.bufdelete()
  else
    vim.cmd(opts.bang and "wq!" or "wq")
  end
end, { bang = true, desc = "Write + close buffer if multiple, else :wq" })

-- :quit and :quit! — longhand for :q / :q!.
vim.api.nvim_create_user_command("Quit", function(opts)
  if has_multiple_buffers() then
    Snacks.bufdelete({ force = opts.bang })
  else
    vim.cmd(opts.bang and "quit!" or "quit")
  end
end, { bang = true, desc = "Close buffer if multiple, else :quit" })

-- Command-line abbreviations. Each guard checks the cmdline matches the
-- bare command exactly, so :Qq / :qall / :wqa / :quitall etc. stay native.
-- The bang form works automatically: when you type `:q!`, the abbreviation
-- fires at `!` (a non-keyword char) when getcmdline() is still 'q', expands
-- `q` → `Q`, then `!` is appended → `:Q!` (which our Q command handles via
-- `{ bang = true }`). Same trick for :wq! and :quit!.
vim.cmd([[
  cnoreabbrev <expr> q    (getcmdtype() ==# ':' && getcmdline() ==# 'q')    ? 'Q'    : 'q'
  cnoreabbrev <expr> wq   (getcmdtype() ==# ':' && getcmdline() ==# 'wq')   ? 'Wq'   : 'wq'
  cnoreabbrev <expr> quit (getcmdtype() ==# ':' && getcmdline() ==# 'quit') ? 'Quit' : 'quit'
]])

-- Focus mode (Goyo + Limelight equivalent, both rolled into Snacks.zen):
-- <leader>w  — full zen: centered narrow window, rest of the UI fully hidden
-- <leader>W  — zoom: maximised single window, no dim (good for code reading)
-- (LazyVim also pre-binds zen to <leader>uz; we add <leader>w as well to
-- match vim muscle memory from goyo/limelight.)
--
-- Tuning notes:
--   - `width = 90` is narrower than the snacks default of 120. Tune to taste.
--   - We disable the `dim` toggle because the opaque backdrop already hides
--     everything outside the focus window, so dimming is redundant.
--   - The backdrop's `bg` is read from the current `Normal` highlight so it
--     matches whatever theme is active (light or dark) — the backdrop ends
--     up invisible against the editor bg, giving a clean "single column of
--     text floating in nothing" look.
--   - Writing-mode `wo` overrides: hide line numbers and sign column for a
--     pure-content view; enable wrap + linebreak so prose flows naturally
--     at word boundaries instead of mid-word.
vim.keymap.set("n", "<leader>w", function()
  local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
  local bg = normal_bg and string.format("#%06x", normal_bg) or nil
  Snacks.zen({
    toggles = { dim = false },
    win = {
      width = 70,    -- narrow column for prose; tune to taste
      height = 0.8,  -- 80% of terminal height → ~10% margin top and bottom
      backdrop = { transparent = false, blend = 0, bg = bg },
      wo = {
        number = false,         -- hide absolute line numbers
        relativenumber = false, -- hide relative line numbers
        signcolumn = "no",      -- hide diagnostic / git-sign gutter
        wrap = true,            -- wrap long prose lines
        linebreak = true,       -- wrap at word boundaries, not mid-word
      },
    },
  })
end, { desc = "Toggle Zen Mode (writing)" })

vim.keymap.set("n", "<leader>W", function() Snacks.zen.zoom() end, { desc = "Toggle Zoom (full-screen)" })

-- Tab-page management. `tn` = "tab new" — opens a new vim tab page (which
-- LazyVim shows on the tabline above the bufferline; cycle with gt/gT, the
-- bufferline cycle keymap we set earlier, which… also moves through buffers).
-- Note: this shadows the built-in `t` motion (jump-till) ONLY when the next
-- key is `n` — `tx`, `tc`, etc. still work normally. If `t` to land before
-- the next `n` matters to you, switch this to `<leader>tn` instead.
vim.keymap.set("n", "tn", "<cmd>tabnew<cr>", { desc = "New tab page" })
