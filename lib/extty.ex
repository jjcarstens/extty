defmodule ExTTY do
  use GenServer
  require Record
  require Logger

  if String.to_integer(System.otp_release()) < 26 do
    @empty_buf {[], [], 0}
    @tty_cli :tty_cli_legacy
  else
    @empty_buf {[], {[], []}, [], 0}
    @tty_cli :tty_cli
  end

  Record.defrecord(:tty_pty, Record.extract(:tty_pty, from: "src/tty_pty.hrl"))

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec send_text(GenServer.server(), String.t()) :: :ok
  def send_text(tty, text) do
    GenServer.call(tty, {:send, text})
  end

  @spec window_change(GenServer.server(), non_neg_integer(), non_neg_integer()) :: :ok
  def window_change(tty, width, height) do
    GenServer.call(tty, {:window_change, width, height})
  end

  @impl GenServer
  def init(opts) do
    handler = Keyword.get(opts, :handler)
    type = Keyword.get(opts, :type, :elixir)
    shell_opts = Keyword.get(opts, :shell_opts, [])
    remsh = Keyword.get(opts, :remsh)
    pty = tty_pty(term: "xterm", width: 80, height: 24, modes: [echo: true, onlcr: 1])

    {:ok,
     %{
       handler: handler,
       pty: pty,
       buf: @empty_buf,
       group: nil,
       type: type,
       shell_opts: shell_opts,
       remsh: remsh
     }, {:continue, :start_shell}}
  end

  @impl GenServer
  def handle_continue(:start_shell, state) do
    {:noreply, start_shell(state)}
  end

  @impl GenServer
  def handle_call({:send, text}, _from, state) do
    text |> to_charlist() |> @tty_cli.to_group(state.group)

    {:reply, :ok, state}
  end

  def handle_call({:window_change, width, height}, _from, state) do
    old_pty = state.pty
    new_pty = tty_pty(old_pty, width: width, height: height)

    {chars, new_buf} =
      @tty_cli.io_request({:window_change, old_pty}, state.buf, new_pty, :undefined)

    send_data(chars, state)

    {:reply, :ok, %{state | pty: new_pty, buf: new_buf}}
  end

  @impl GenServer
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
    {chars, new_buf} = @tty_cli.io_request(request, state.buf, state.pty, group)
    send_data(chars, state)
    {:noreply, %{state | buf: new_buf}}
  end

  @impl GenServer
  def terminate(reason, state) do
    # The `IEx.Server` and `IEx.Evaluator` don't go away with a simple `:normal` exit.
    Process.exit(state.group, :kill)
    :ok
  end

  defp start_shell(state) do
    %{
      state
      | group: :group.start(self(), shell_spawner(state), echo: true, expand_below: false),
        buf: @empty_buf
    }
  end

  defp send_data(chars, %{handler: handler}) do
    str = IO.chardata_to_string(chars)

    if handler do
      send(handler, {:tty_data, str})
    else
      Logger.debug("[#{inspect(__MODULE__)}] tty_data - #{inspect(str)}")
    end
  end

  defp shell_spawner(%{remsh: node} = state) when not is_nil(node) do
    {m, f, a} = shell_spawner(%{type: state.type, shell_opts: state.shell_opts})

    {:erpc, :call, [node, m, f, a]}
  end

  defp shell_spawner(%{type: :erlang, shell_opts: opts}) do
    {:shell, :start, opts}
  end

  if Version.match?(System.version(), ">= 1.17.0") do
    defp shell_spawner(%{type: :elixir, shell_opts: opts}) do
      # :iex.start/0 is now the recommended way to start IEx, but
      # we want to support the options so we're using the mostly
      # private API :iex.start/2 which takes the options as a
      # keyword list and an MFA (which is same one used in :iex.start/0).
      flat_opts =
        opts
        |> List.flatten()
        |> Enum.reduce([], fn
          {:dot_iex_path, path}, acc ->
            # Elixir 1.17 uses :dot_iex_path and Elixir 1.18 uses :dot_iex,
            # so pass both.
            [{:dot_iex_path, path}, {:dot_iex, path} | acc]

          kv, acc ->
            [kv | acc]
        end)

      {:iex, :start, [flat_opts, {:elixir_utils, :noop, []}]}
    end
  else
    defp shell_spawner(%{type: :elixir, shell_opts: opts}) do
      {Elixir.IEx, :start, opts}
    end
  end

  defp shell_spawner(state) do
    Logger.warning(
      "[#{inspect(__MODULE__)}] unknown shell type #{inspect(state.type)} - defaulting to :elixir"
    )

    shell_spawner(%{state | type: :elixir})
  end
end
