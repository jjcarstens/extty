defmodule ExTTY do
  use GenServer
  require Record
  require Logger

  Record.defrecord(:tty_pty, Record.extract(:tty_pty, from: "src/tty_pty.hrl"))

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec send_text(GenServer.name(), String.t()) :: :ok
  def send_text(tty \\ __MODULE__, text) do
    GenServer.call(tty, {:send, text})
  end

  @spec window_change(GenServer.name(), non_neg_integer(), non_neg_integer()) :: :ok
  def window_change(tty \\ __MODULE__, width, height) do
    GenServer.call(tty, {:window_change, width, height})
  end

  @impl true
  def init(opts) do
    handler = Keyword.get(opts, :handler)
    type = Keyword.get(opts, :type, :elixir)
    shell_opts = Keyword.get(opts, :shell_opts, [])
    pty = tty_pty(term: "xterm", width: 80, height: 24, modes: [echo: true])
    {:ok, %{handler: handler, pty: pty, buf: empty_buf(), group: nil, type: type, shell_opts: shell_opts}, {:continue, :start_shell}}
  end

  @impl true
  def handle_continue(:start_shell, state) do
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

    send_data(chars, state)

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
    send_data(chars, state)
    {:noreply, %{state | buf: new_buf}}
  end

  defp start_shell(state) do
    %{state | group: :group.start(self(), shell_spawner(state), [{:echo, true}]), buf: empty_buf()}
  end

  defp empty_buf(), do: {[], [], 0}

  defp send_data(chars, %{handler: handler}) do
    str = IO.chardata_to_string(chars)

    if handler do
      send handler, {:tty_data, str}
    else
      Logger.debug("[#{inspect(__MODULE__)}] tty_data - #{inspect(str)}")
    end
  end

  defp shell_spawner(%{type: :erlang, shell_opts: opts}) do
    {:shell, :start, opts}
  end

  defp shell_spawner(%{type: :elixir, shell_opts: opts}) do
    {Elixir.IEx, :start, opts}
  end

  defp shell_spawner(state) do
    Logger.warn("[#{inspect(__MODULE__)}] unknown shell type #{inspect(state.type)} - defaulting to :elixir")
    shell_spawner(%{state | type: :elixir})
  end
end
