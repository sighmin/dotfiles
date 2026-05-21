-- blink.cmp: completion engine.
--
-- super-tab preset: Tab accepts the visible suggestion (and jumps snippet
-- placeholders if a snippet is active). <CR> is left as a plain newline.
--
-- Override the navigation keys: Ctrl-j / Ctrl-k cycle through the
-- completion menu instead of the preset's Ctrl-n / Ctrl-p. Note this
-- shadows blink's default <C-k> binding for signature help — use
-- <C-s> or `:lua vim.lsp.buf.signature_help()` if you need that.
return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      preset = "super-tab",
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
    },
  },
}
