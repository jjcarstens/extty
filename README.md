# ExTTY

[![Hex version](https://img.shields.io/hexpm/v/extty.svg "Hex version")](https://hex.pm/packages/extty)
[![CircleCI](https://circleci.com/gh/jjcarstens/extty.svg?style=svg)](https://circleci.com/gh/jjcarstens/extty)

Run an Elixir or Erlang shell as a GenServer process

# Installation

Install `extty` by adding it to your list of dependencies in `mix.exs`:

```elixir
def deps() do
  [
    {:extty, "~> 0.2"}
  ]
end
```

# Usage

This is heavily adapted from [`ssh_cli.erl`](https://github.com/erlang/otp/blob/master/lib/ssh/src/ssh_cli.erl)
and functions much like the SSH console implementation.

This will start a terminal shell process in a GenServer. You can then send ANSI text
to it to behave like a normal TTY. When starting the shell, you must specify a handler
pid to receive the returned text data. The incoming message will be formatted as
`{:tty_data, String.t()}`

```elixir

iex()> {:ok, tty} = ExTTY.start_link(handler: self())
iex()> flush()
{:tty_data, "Interactive Elixir (1.10.3) - press Ctrl+C to exit (type h() ENTER for help)\r\n"}
{:tty_data, "iex(1)> "}
iex()> ExTTY.send_text(tty, "1+1\n")
:ok
iex()> flush()
{:tty_data, "1+1\r\n"}
{:tty_data, "\e[33m2\e[0m\r\n"}
{:tty_data, "iex(2)> "}
```

## Console

You can use `ExTTY` with `Circuits.UART` as an interactive console on a serial
port. This is useful in situations where you want multiple consoles accessible
such as on UART pins and HDMI:

```elixir
ExTTY.Console.start_link(serial_port: "ttyAMA0")
```
