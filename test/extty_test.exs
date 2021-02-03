defmodule ExTTYTest do
  use ExUnit.Case
  doctest ExTTY

  test "that Elixir starts" do
    start_supervised!({ExTTY, [handler: self()]})

    assert_receive {:tty_data, message}
    assert message =~ "Interactive Elixir"

    # Expect a prompt
    assert_receive {:tty_data, "iex(1)> "}

    # Nothing else
    refute_receive _
  end

  test "that Erlang starts" do
    start_supervised!({ExTTY, [type: :erlang, handler: self()]})

    assert_receive {:tty_data, message}
    assert message =~ "Eshell"

    # Expect a prompt
    assert_receive {:tty_data, "1> "}

    # Nothing else
    refute_receive _
  end

  test "interactive addition" do
    pid = start_supervised!({ExTTY, [handler: self()]})

    assert_receive {:tty_data, message}
    assert message =~ "Interactive Elixir"

    # Expect a prompt
    assert_receive {:tty_data, "iex(1)> "}

    :ok = ExTTY.send_text(pid, "1+1\r")

    # Expect it to be echoed back
    assert_receive {:tty_data, "1+1\r\n"}

    # Expect the response with ANSI colors
    assert_receive {:tty_data, "\e[33m2\e[0m\r\n"}

    # Expect the next prompt
    assert_receive {:tty_data, "iex(2)> "}

    # And nothing else
    refute_receive _
  end

  test "window change redraws prompt" do
    pid = start_supervised!({ExTTY, [handler: self()]})

    assert_receive {:tty_data, message}
    assert message =~ "Interactive Elixir"

    # Expect a prompt
    assert_receive {:tty_data, "iex(1)> "}

    :ok = ExTTY.window_change(pid, 40, 20)

    # Redrawn prompt
    assert_receive {:tty_data, "\e[8Diex(1)> "}

    # And nothing else
    refute_receive _
  end
end
