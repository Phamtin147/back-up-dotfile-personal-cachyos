require("full-border"):setup {
	-- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
	type = ui.Border.ROUNDED,
}
require("yatline"):setup({
  header_line = {
    left = {
      section_a = {
        { type = "line", name = "tabs" },
      },
      section_b = {},
      section_c = {},
    },
    right = {
      section_a = {
        { type = "string", name = "date", params = { "%A, %d %B %Y" } },
      },
      section_b = {
        { type = "string", name = "date", params = { "%H:%M" } },
      },
      section_c = {},
    },
  },
})
require("recycle-bin"):setup()
