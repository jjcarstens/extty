defmodule ExTTY.Console do
  use GenServer

  @uart_opts [
    framing: Circuits.UART.Framing.None,
    speed: 115_200,
    active: true
  ]

  def start_link(opts) do
    serial_port = Keyword.fetch!(opts, :serial_port)
    name = :"console-#{serial_port}"
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    serial_port = opts[:serial_port]
    {:ok, uart} = Circuits.UART.start_link(name: :"uart-#{serial_port}")
    opts = Keyword.merge(@uart_opts, opts)
    :ok = Circuits.UART.open(uart, serial_port, opts)
    {:ok, %{uart: uart, tty: nil}, {:continue, :start_tty}}
  end

  @impl GenServer
  def handle_continue(:start_tty, state) do
    # Make sure TTY is started after UART since it may send some data on load
    {:ok, tty} = ExTTY.start_link(handler: self())
    {:noreply, %{state | tty: tty}}
  end

  @impl GenServer
  def handle_info({:tty_data, data}, state) do
    Circuits.UART.write(state.uart, data)

    # Make sure all the bytes are written before continue
    Circuits.UART.drain(state.uart)
    {:noreply, state}
  end

  def handle_info({:circuits_uart, _serial_port, data}, state) do
    ExTTY.send_text(state.tty, data)
  end
end
