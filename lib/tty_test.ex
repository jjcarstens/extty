defmodule TtyTest do
  use GenServer
  require Record

  Record.defrecord(:tty_pty, Record.extract(:tty_pty, from: "src/tty_pty.hrl"))

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec send_text(String.t()) :: :ok
  def send_text(text) do
    GenServer.call(__MODULE__, {:send, text})
  end

  def window_change(width, height) do
    GenServer.call(__MODULE__, {:window_change, width, height})
  end

  @impl true
  def init(_args) do
    pty = tty_pty(term: "xterm", width: 80, height: 24, modes: [echo: true])
    {:ok, %{pty: pty, buf: empty_buf(), group: nil}, {:continue, :continue}}
  end

  @impl true
  def handle_continue(:continue, state) do
    {:noreply, start_shell(state)}
  end

  @impl true
  def handle_call({:send, text}, _from, state) do
    text |> to_charlist() |> :tty_cli.to_group(state.group)

    {:reply, :ok, state}
  end

  def handle_call({:window_change, width, height}, _from, state) do
    old_pty = state.pty
    new_pty = tty_pty(old_pty, width: width, height: height)

    {chars, new_buf} =
      :tty_cli.io_request({:window_change, old_pty}, state.buf, new_pty, :undefined)

    IO.puts("Got: #{inspect(IO.iodata_to_binary(chars))}")

    {:reply, :ok, %{state | pty: new_pty, buf: new_buf}}
  end

  @impl true
  def handle_info({group, :set_unicode_state, _arg}, %{group: group} = state) do
    send(group, {self(), :set_unicode_state, true})
    {:noreply, state}
  end

  def handle_info({group, :get_unicode_state}, %{group: group} = state) do
    send(group, {self(), :get_unicode_state, true})
    {:noreply, state}
  end

  def handle_info({group, :tty_geometry}, %{group: group} = state) do
    geometry = {tty_pty(state.pty, :width), tty_pty(state.pty, :height)}
    send(group, {self(), :tty_geometry, geometry})
    {:noreply, state}
  end

  def handle_info({group, request}, %{group: group} = state) do
    {chars, new_buf} = :tty_cli.io_request(request, state.buf, state.pty, group)
    IO.puts("Got: #{inspect(IO.chardata_to_string(chars))}")
    {:noreply, %{state | buf: new_buf}}
  end

  defp start_shell(state) do
    # shell_spawner = {:shell, :start, []}
    shell_spawner = {Elixir.IEx, :start, []}

    %{state | group: :group.start(self(), shell_spawner, [{:echo, true}]), buf: empty_buf()}
  end

  defp empty_buf(), do: {[], [], 0}
end
