uv = require "luv"
local stdin = uv.new_tty(0, true)
uv.tty_set_mode(stdin, 1)
stdin:close()
uv.tty_reset_mode()
