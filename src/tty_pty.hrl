-ifndef(TTY_PTY_HRL).
-define(TTY_PTY_HRL, 1).

-record(tty_pty, {term = "", % e.g. "xterm"
		  width = 80,
		  height = 25,
		  pixel_width = 1024,
		  pixel_height = 768,
		  modes = <<>>}).

-endif. % TTY_PTY_HRL defined
