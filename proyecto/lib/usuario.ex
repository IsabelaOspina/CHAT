defmodule Proyecto.Usuario do
  use GenServer

  @contraseñas :proyecto_contraseñas

  defp init_contraseñas do
    if :ets.whereis(@contraseñas) == :undefined do
      :ets.new(@contraseñas, [:named_table, :set, :public])
    end
  end

  def crear_usuario(nombre) do
    init_contraseñas()
    case :ets.lookup(@contraseñas, nombre) do
      [] ->
        contraseña = IO.gets("Ingresa una contraseña para el usuario #{nombre}: ") |> String.trim()
        :ets.insert(@contraseñas, {nombre, contraseña})
        case GenServer.start_link(__MODULE__, {nombre, contraseña}, name: String.to_atom(nombre)) do
          {:ok, _pid} ->
            IO.puts("Usuario #{nombre} creado")
            start(nombre)
          {:error, reason} ->
            IO.puts("Error al crear el usuario: #{inspect(reason)}")
        end
      _ ->
        IO.puts("El usuario ya existe. Usa reconectar_usuario/1 para iniciar sesión.")
    end
  end

  def reconectar_usuario(nombre) do
    init_contraseñas()
    case :ets.lookup(@contraseñas, nombre) do
      [{^nombre, contraseña_guardada}] ->
        contraseña = IO.gets("Ingresa la contraseña para el usuario #{nombre}: ") |> String.trim()
        if contraseña == contraseña_guardada do
          case GenServer.start_link(__MODULE__, {nombre, contraseña}, name: String.to_atom(nombre)) do
            {:ok, _pid} ->
              IO.puts("Usuario #{nombre} reconectado")
              start(nombre)
            {:error, {:already_started, _}} ->
              IO.puts("Usuario ya conectado, usando sesión existente.")
              start(nombre)
            {:error, reason} ->
              IO.puts("Error al reconectar el usuario: #{inspect(reason)}")
          end
        else
          IO.puts("Contraseña incorrecta.")
        end
      _ ->
        IO.puts("Usuario no encontrado. Usa crear_usuario/1 para crear uno nuevo.")
    end
  end

  def init({nombre, contraseña}) do
    {:ok, %{nombre: nombre, contraseña: contraseña}}
  end

  def start(nombre) do
    case GenServer.call({:global, Proyecto.Servidor}, {:connect, nombre, self()}) do
      :ok ->
        IO.puts("Bienvenido a la sala de chat, #{nombre}")
        interactive_mode(nombre)
      {:error, reason} ->
        IO.puts("Error al entrar a la sala: #{reason}")
    end
  end

  def interactive_mode(nombre) do
    IO.puts("""
    Escribe un comando para interactuar.
    /join nombre_sala               - Unirse a una sala de chat
    /create nombre_sala             - Crear una nueva sala de chat
    /leave                          - Abandonar la sala actual
    /history nombre_sala            - Consultar historial de mensajes de una sala
    /search nombre_sala palabra     - Buscar mensajes por palabra en una sala
    /list                           - Mostrar usuarios conectados
    /exit                           - Salir del chat

    Para enviar un mensaje, solo escribe el texto y se enviará a la sala en la que estás unido.
    """)
    # Proceso para leer comandos del usuario
    spawn(fn -> command_loop(nombre) end)
    # Proceso principal escucha mensajes en tiempo real
    listen(nombre)
  end

  defp listen(nombre) do
    receive do
      {:mensaje, mensaje} ->
        IO.puts(mensaje)
        listen(nombre)
    end
  end

  defp command_loop(nombre) do
    comando = IO.gets("> ") |> String.trim()
    case process_command(nombre, comando) do
      :exit -> :ok
      _ -> command_loop(nombre)
    end
  end

  defp process_command(nombre, comando) do
    cond do
      comando == "/list" ->
        case GenServer.call({:global, Proyecto.Servidor}, :listar_usuarios) do
          {:ok, usuarios} ->
            IO.puts("Usuarios conectados:")
            Enum.each(usuarios, &IO.puts("- #{&1}"))
          {:error, reason} ->
            IO.puts("Error al obtener la lista de usuarios: #{reason}")
        end

      String.starts_with?(comando, "/history ") ->
        [_, sala | _] = String.split(comando, " ", parts: 3)
        case GenServer.call({:global, Proyecto.Servidor}, {:listar_historial, sala}) do
          {:ok, historial} ->
            IO.puts("Historial de mensajes de #{sala}:")
            Enum.each(Enum.reverse(historial), &IO.puts(&1))
          {:error, reason} ->
            IO.puts("Error al obtener el historial: #{reason}")
        end

      String.starts_with?(comando, "/search ") ->
        [_, sala, palabra | _] = String.split(comando, " ", parts: 4)
        case GenServer.call({:global, Proyecto.Servidor}, {:buscar_mensajes, sala, palabra}) do
          {:ok, encontrados} ->
            IO.puts("Mensajes encontrados en #{sala}:")
            Enum.each(Enum.reverse(encontrados), &IO.puts(&1))
          {:error, reason} ->
            IO.puts("Error en la búsqueda: #{reason}")
        end

      String.starts_with?(comando, "/create ") ->
        nombre_sala = String.replace_prefix(comando, "/create ", "")
        case GenServer.call({:global, Proyecto.Servidor}, {:crear_sala, nombre_sala}) do
          :ok -> IO.puts("Sala #{nombre_sala} creada.")
          {:error, reason} -> IO.puts("Error al crear la sala: #{reason}")
        end

      String.starts_with?(comando, "/join ") ->
        nombre_sala = String.replace_prefix(comando, "/join ", "")
        case GenServer.call({:global, Proyecto.Servidor}, {:entrar_sala, nombre, nombre_sala}) do
          :ok -> IO.puts("Te has unido a la sala #{nombre_sala}.")
          {:error, reason} -> IO.puts("Error al entrar a la sala: #{reason}")
        end

      comando == "/leave" ->
        case GenServer.call({:global, Proyecto.Servidor}, {:abandonar_sala, nombre}) do
          :ok -> IO.puts("Has abandonado la sala.")
          {:error, reason} -> IO.puts("Error al abandonar la sala: #{reason}")
        end

      comando == "/exit" ->
        IO.puts("Has salido del chat")
        :exit

      String.starts_with?(comando, "/") ->
        IO.puts("Comando no reconocido.")
        :ok

      true ->
        # Si no es comando, se interpreta como mensaje a la sala actual
        case GenServer.call({:global, Proyecto.Servidor}, {:obtener_sala_actual, nombre}) do
          {:ok, nil} ->
            IO.puts("No estás unido a ninguna sala. Usa /join nombre_sala para unirte.")
          {:ok, sala_actual} ->
            GenServer.cast({:global, Proyecto.Servidor}, {:enviar_mensaje, nombre, sala_actual, comando})
          {:error, reason} ->
            IO.puts("Error al obtener la sala actual: #{reason}")
        end
        :ok
    end
  end
end
