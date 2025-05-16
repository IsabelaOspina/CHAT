defmodule Proyecto.Servidor do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{
      usuarios: %{}, # %{nombre => %{pid, sala}}
      salas: %{"general" => []}, # %{sala => [usuarios]}
      mensajes: %{"general" => []} # %{sala => [mensajes]}
    }, name: {:global, __MODULE__})
  end

  def init(state), do: {:ok, state}

  # Conectar usuario
  def handle_call({:connect, nombre, pid}, _from, state) do
    if Map.has_key?(state.usuarios, nombre) do
      {:reply, {:error, "Usuario ya conectado"}, state}
    else
      usuarios = Map.put(state.usuarios, nombre, %{pid: pid, sala: "general"})
      salas = Map.update!(state.salas, "general", fn usrs -> [nombre | usrs] end)
      {:reply, :ok, %{state | usuarios: usuarios, salas: salas}}
    end
  end

  # Crear sala
  def handle_call({:crear_sala, nombre_sala}, _from, state) do
    if Map.has_key?(state.salas, nombre_sala) do
      {:reply, {:error, "La sala #{nombre_sala} ya existe"}, state}
    else
      salas = Map.put(state.salas, nombre_sala, [])
      mensajes = Map.put(state.mensajes, nombre_sala, [])
      {:reply, :ok, %{state | salas: salas, mensajes: mensajes}}
    end
  end

  # Unirse a sala
  def handle_call({:entrar_sala, nombre, nombre_sala}, _from, state) do
    if not Map.has_key?(state.salas, nombre_sala) do
      {:reply, {:error, "La sala #{nombre_sala} no existe"}, state}
    else
      sala_anterior = state.usuarios[nombre][:sala]
      # Quitar usuario de la sala anterior
      salas =
        state.salas
        |> Map.update!(sala_anterior, fn lista -> List.delete(lista, nombre) end)
        |> Map.update!(nombre_sala, fn lista -> [nombre | lista] end)
      usuarios = Map.update!(state.usuarios, nombre, &Map.put(&1, :sala, nombre_sala))
      {:reply, :ok, %{state | usuarios: usuarios, salas: salas}}
    end
  end

  # Abandonar sala (opcional)
  def handle_call({:abandonar_sala, nombre}, _from, state) do
    sala = state.usuarios[nombre][:sala]
    salas = update_in(state.salas[sala], fn lista -> List.delete(List.wrap(lista), nombre) end)
    usuarios = Map.update!(state.usuarios, nombre, &Map.put(&1, :sala, nil))
    {:reply, :ok, %{state | usuarios: usuarios, salas: salas}}
  end

  # Listar usuarios conectados
  def handle_call(:listar_usuarios, _from, state) do
    {:reply, {:ok, Map.keys(state.usuarios)}, state}
  end

  # Listar historial de una sala
  def handle_call({:listar_historial, sala}, _from, state) do
    {:reply, {:ok, Map.get(state.mensajes, sala, [])}, state}
  end

  # Buscar mensajes por palabra clave en una sala
  def handle_call({:buscar_mensajes, sala, palabra}, _from, state) do
    mensajes = Map.get(state.mensajes, sala, [])
    encontrados = Enum.filter(mensajes, fn msg -> String.contains?(msg, palabra) end)
    {:reply, {:ok, encontrados}, state}
  end

  # Obtener la sala actual de un usuario
  def handle_call({:obtener_sala_actual, nombre}, _from, state) do
    case Map.get(state.usuarios, nombre) do
      nil -> {:reply, {:error, "Usuario no encontrado"}, state}
      usuario -> {:reply, {:ok, usuario[:sala]}, state}
    end
  end

  # Enviar mensaje a la sala
  def handle_cast({:enviar_mensaje, usuario, sala, mensaje}, state) do
    # Obtener fecha y hora actual
    {{año, mes, dia}, {hora, min, seg}} = :calendar.local_time()
    timestamp = :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B", [año, mes, dia, hora, min, seg]) |> IO.iodata_to_binary()
    # Formato del mensaje
    mensaje_formateado = "[#{timestamp}] [#{sala}] #{usuario}: #{mensaje}"
    mensajes = Map.update(state.mensajes, sala, [mensaje_formateado], fn ms -> [mensaje_formateado | ms] end)
    # Notificar a todos los usuarios de la sala
    usuarios_en_sala = Map.get(state.salas, sala, [])
    Enum.each(usuarios_en_sala, fn usuario_nombre ->
      if Map.has_key?(state.usuarios, usuario_nombre) do
        pid = state.usuarios[usuario_nombre][:pid]
        send(pid, {:mensaje, mensaje_formateado})
      end
    end)
    guardar_mensaje(sala, mensaje_formateado)
    {:noreply, %{state | mensajes: mensajes}}
  end

  # Guardar mensajes en archivo
  defp guardar_mensaje(sala, mensaje) do
    File.write!("mensajes_#{sala}.txt", mensaje <> "\n", [:append])
  end
end
