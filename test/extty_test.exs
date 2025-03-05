defmodule ExTTYTest do
  use ExUnit.Case
  doctest ExTTY

  test "that Elixir starts by default" do
    start_supervised!({ExTTY, [handler: self()]})

    assert_receive {:tty_data, message}
    assert message =~ "Interactive Elixir"

    # Expect a prompt
    assert_receive {:tty_data, "iex(1)> "}

    # Nothing else
    refute_receive _
  end

  @tag :tmp_dir
  test "that Elixir starts with dot_iex_path option", %{tmp_dir: tmp_dir} do
    dot_iex = """
    IO.puts("Hello from iex.exs")
    """

    dot_iex_path = Path.join(tmp_dir, "iex.exs")
    File.write!(dot_iex_path, dot_iex)

    start_supervised!(
      {ExTTY, [handler: self(), type: :elixir, shell_opts: [[dot_iex_path: dot_iex_path]]]}
    )

    assert_receive {:tty_data, message}
    assert message =~ "Interactive Elixir"

    assert_receive {:tty_data, message}
    assert message =~ "Hello from iex.exs"

    # Expect a prompt
    assert_receive {:tty_data, "iex(1)> "}

    # # Nothing else
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

    # Disable colors to make tests easier
    :ok = ExTTY.send_text(pid, "IEx.configure(colors: [enabled: false])\r")

    # Expect it to be echoed back
    assert_receive {:tty_data, "IEx.configure(colors: [enabled: false])\r\n" <> _}

    # Expect the response without ANSI colors
    assert_receive {:tty_data, ":ok\r\n"}

    # Expect the next prompt
    assert_receive {:tty_data, "iex(2)> "}

    :ok = ExTTY.send_text(pid, "1+1\r")

    # Expect it to be echoed back
    assert_receive {:tty_data, "1+1\r\n" <> _}

    # Expect the response without ANSI colors
    assert_receive {:tty_data, "2\r\n"}

    # Expect the next prompt
    assert_receive {:tty_data, "iex(3)> "}
  end

  test "window change acknowledged" do
    pid = start_supervised!({ExTTY, [handler: self()]})

    assert_receive {:tty_data, message}
    assert message =~ "Interactive Elixir"

    # Expect a prompt
    assert_receive {:tty_data, "iex(1)> "}

    :ok = ExTTY.window_change(pid, 40, 20)

    # This is what the code does, so check that it works the same
    assert_receive {:tty_data, ""}

    # And nothing else
    refute_receive _
  end

  test "group processes (i.e. IEx.Evaluator) are cleaned up" do
    {:ok, iex_pid} = ExTTY.start_link(handler: self(), type: :elixir, shell_opts: [])
    group = :sys.get_state(iex_pid).group
    ref = Process.monitor(iex_pid)

    Process.sleep(500)

    count =
      Enum.count(Process.list(), fn pid ->
        info = Process.info(pid)
        iex_pid in info[:links] or group == info[:group_leader]
      end)

    assert count >= 1

    GenServer.stop(iex_pid, :normal, 10_000)

    assert_receive {:DOWN, ^ref, :process, ^iex_pid, _}

    Process.sleep(500)

    count =
      Enum.count(Process.list(), fn pid ->
        info = Process.info(pid)
        iex_pid in info[:links] or group == info[:group_leader]
      end)

    assert count == 0
  end
end
