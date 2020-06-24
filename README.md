# TtyTest

```elixir
$ iex -S mix                                                        master*
Erlang/OTP 23 [erts-11.0.2] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [hipe]

Interactive Elixir (1.10.3) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> TtyTest.start_link([])
{:ok, #PID<0.149.0>}
Got: "Interactive Elixir (1.10.3) - press Ctrl+C to exit (type h() ENTER for help)\r\n"
Got: "iex(1)> "
iex(2)> TtyTest.send_text("1+1\n")
Got: "1+1\r\n"
:ok
Got: "\e[33m2\e[0m\r\n"
Got: "iex(2)> "
iex(3)>
```
