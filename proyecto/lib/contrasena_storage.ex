defmodule Proyecto.ContrasenaStorage do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    # Solo crea la tabla si no existe (evita error si ya existe)
    if :ets.whereis(:proyecto_contraseñas) == :undefined do
      :ets.new(:proyecto_contraseñas, [:named_table, :set, :public, read_concurrency: true])
    end
    {:ok, %{}}
  end
end
