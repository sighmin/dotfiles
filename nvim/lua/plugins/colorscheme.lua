-- Atom One theme for nvim, dynamically switching with macOS system appearance.
-- Mirrors the ghostty config (`theme = light:Atom One Light,dark:Atom One Dark`)
-- and the tmux setup driven by tmux-dark-notify.
--
-- Plumbing notes:
--   - The colorscheme is navarasu/onedark.nvim, which ships matching `dark` and
--     `light` styles drawn from the Atom One palette.
--   - Live switching is driven by `dark-notify` (Homebrew), the same CLI that
--     tmux-dark-notify uses. It listens to NSWorkspace appearance notifications
--     and prints `light` or `dark` to stdout on every change.
--   - We deliberately avoid `defaults read -g AppleInterfaceStyle` because that
--     key sticks at "Dark" when macOS is set to Auto appearance — `dark-notify`
--     (and AppleScript's `dark mode` property) report the live rendered state.

local uv = vim.uv or vim.loop

local function apply_style(style)
  vim.o.background = style
  require("onedark").setup({ style = style })
  require("onedark").load()
end

-- One-shot initial detection at config-eval time. We use `dark-notify --exit`
-- which prints the current appearance and exits — same signal we'll subscribe
-- to for live updates below. Fall back to "dark" if the CLI isn't installed.
local function detect_initial_style()
  local handle = io.popen("dark-notify --exit 2>/dev/null")
  if not handle then return "dark" end
  local out = handle:read("*a") or ""
  handle:close()
  return out:match("light") and "light" or "dark"
end

local initial_style = detect_initial_style()
vim.o.background = initial_style -- set early so plugins that query it see the right value

-- Start a long-running dark-notify watcher after nvim has finished starting,
-- so that onedark.nvim is loaded by the time the first event fires.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if vim.fn.executable("dark-notify") == 0 then return end

    local stdout = uv.new_pipe(false)
    local handle = uv.spawn("dark-notify", {
      args = { "--only-changes" }, -- we already detected the initial value
      stdio = { nil, stdout, nil },
    }, function() end)

    if not handle then
      stdout:close()
      return
    end

    uv.read_start(stdout, function(err, data)
      if err or not data then return end
      for line in data:gmatch("[^\r\n]+") do
        local style = line == "light" and "light" or "dark"
        vim.schedule(function() apply_style(style) end)
      end
    end)

    -- Best-effort cleanup so we don't leak the child process on :qa.
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        pcall(uv.process_kill, handle, "sigterm")
        pcall(uv.close, stdout)
      end,
    })
  end,
})

return {
  -- The colorscheme
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000, -- load before other plugins so highlights apply cleanly
    opts = { style = initial_style }, -- `dark` ≈ Atom One Dark, `light` ≈ Atom One Light
  },

  -- Tell LazyVim to use onedark instead of the default tokyonight
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "onedark" },
  },
}
