defmodule Proyecto.Sala do
  use GenServer

  @moduledoc """
  Módulo que representa una sala de chat. Se encarga de almacenar los usuarios
  que están dentro de la sala y el historial de mensajes.
  """

  # API pública

  @doc """
  Inicia una nueva sala con un nombre dado.
  """
  def start_link(nombre) do
    GenServer.start_link(__MODULE__, %{usuarios: [], mensajes: []}, name: via_tuple(nombre))
  end
  @doc """
  Agrega un usuario a la sala.
  """
  def agregar_usuario(nombre_sala, usuario) do
    GenServer.call(via_tuple(nombre_sala), {:agregar_usuario, usuario})
  end

  @doc """
  Elimina un usuario de la sala.
  """
  def eliminar_usuario(nombre_sala, usuario) do
    GenServer.call(via_tuple(nombre_sala), {:eliminar_usuario, usuario})
  end

  @doc """
  Envía un mensaje a la sala.
  """
  def enviar_mensaje(nombre_sala, usuario, mensaje) do
    GenServer.call(via_tuple(nombre_sala), {:enviar_mensaje, usuario, mensaje})
  end

  @doc """
  Obtiene la lista de usuarios en la sala.
  """
  def listar_usuarios(nombre_sala) do
    GenServer.call(via_tuple(nombre_sala), :listar_usuarios)
  end

  @doc """
  Obtiene el historial de mensajes de la sala.
  """
  def listar_mensajes(nombre_sala) do
    GenServer.call(via_tuple(nombre_sala), :listar_mensajes)
  end

  # Implementación interna

  defp via_tuple(nombre), do: {:via, Registry, {Proyecto.Registry, nombre}}

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:agregar_usuario, usuario}, _from, state) do
    if usuario in state.usuarios do
      {:reply, {:error, "El usuario ya está en la sala"}, state}
    else
      {:reply, :ok, %{state | usuarios: [usuario | state.usuarios]}}
    end
  end

  @impl true
  def handle_call({:eliminar_usuario, usuario}, _from, state) do
    if usuario in state.usuarios do
      {:reply, :ok, %{state | usuarios: List.delete(state.usuarios, usuario)}}
    else
      {:reply, {:error, "El usuario no está en la sala"}, state}
    end
  end

  @impl true
  def handle_call({:enviar_mensaje, usuario, mensaje}, _from, state) do
    if usuario in state.usuarios do
      nuevo_mensaje = %{usuario: usuario, mensaje: mensaje, timestamp: DateTime.utc_now()}
      {:reply, :ok, %{state | mensajes: [nuevo_mensaje | state.mensajes]}}
    else
      {:reply, {:error, "El usuario no está en la sala"}, state}
    end
  end

  @impl true
  def handle_call(:listar_usuarios, _from, state) do
    {:reply, {:ok, state.usuarios}, state}
  end

  @impl true
  def handle_call(:listar_mensajes, _from, state) do
    {:reply, {:ok, Enum.reverse(state.mensajes)}, state}
  end
end
