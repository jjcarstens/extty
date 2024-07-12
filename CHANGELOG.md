# Changelog

## v0.4.0

* Adds support for Elixir 1.17
  * This required using a different entry point into IEx and
    adjusts the shape of `:shell_opts` to be a flat keyword list
  * Elixir also renamed `:dot_iex_path` -> `:dot_iex`. The changes
    here account for that for now, but if you previously included
    this in options you'll need to change from
    `shell_opts: [[dot_iex_path: path]]` to `shell_opts: [dot_iex: path]`
* Minimum supported Elixir version is now 1.13

## v0.3.0

* Support Elixir 1.15 / OTP 26 with backwards compatibility

## v0.2.1

* Sync tty_cli.erl with ssh_cli.erl in Erlang
  * `:onlcr` was set so that the CRLF behavior remained the same

## v0.2.0

* Fixes
  * `ExTTY` no longer defaults a `:name` option for GenServer start_link.
  If you relied on the default `ExTTY` name, you will need to pass that or
  a different name as the `:name` option explicitly and use it
  (or the returned pid of `ExTTY.start_link/1`) when calling the
  functions of `ExTTY`:

  ```elixir
  # Named GenServer
  {:ok, _pid} = ExTTY.start_link(name: TTY1)
  ExTTY.send_text(TTY1, "1+1\n")

  # Unnamed GenServer
  {:ok, tty} = ExTTY.start_link()
  ExTTY.send_text(tty, "1+1\n")
  ```

## v0.1.0

Initial release
