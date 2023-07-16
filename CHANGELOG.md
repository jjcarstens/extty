# Changelog

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
