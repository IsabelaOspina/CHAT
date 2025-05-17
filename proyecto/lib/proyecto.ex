defmodule Proyecto.API do
  use Plug.Router

  plug Plug.Static,
    at: "/",
    from: Path.expand("../../frontend", __DIR__),
    only: ~w(index.html style.css main.js)

  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :match
  plug :dispatch

  # Crear usuario
  post "/usuario" do
    # Ya no crees la tabla aquí, solo usa ETS
    case conn.body_params do
      %{"nombre" => nombre, "contraseña" => contraseña} ->
        case :ets.lookup(:proyecto_contraseñas, nombre) do
          [] ->
            :ets.insert(:proyecto_contraseñas, {nombre, contraseña})
            IO.inspect(:ets.tab2list(:proyecto_contraseñas), label: "ETS DESPUES DE REGISTRAR")
            :timer.sleep(100)
            send_resp(conn, 201, Jason.encode!(%{ok: true, usuario: nombre}))
          _ ->
            send_resp(conn, 400, Jason.encode!(%{ok: false, error: "El usuario ya está registrado. Usa Entrar."}))
        end
      _ ->
        send_resp(conn, 400, Jason.encode!(%{ok: false, error: "Faltan parámetros: nombre y contraseña"}))
    end
  end

  # Reconectar usuario
  post "/usuario/reconectar" do
    # Ya no crees la tabla aquí, solo usa ETS
    %{"nombre" => nombre, "contraseña" => contraseña} = conn.body_params
    IO.inspect({nombre, contraseña}, label: "RECONEXION PARAMS")
    contenido_ets = :ets.tab2list(:proyecto_contraseñas)
    IO.inspect(contenido_ets, label: "CONTENIDO ETS")
    case :ets.lookup(:proyecto_contraseñas, nombre) do
      [{^nombre, contraseña_guardada}] ->
        IO.inspect({contraseña, contraseña_guardada}, label: "CONTRASEÑAS")
        if contraseña == contraseña_guardada do
          case GenServer.start_link(Proyecto.Usuario, {nombre, contraseña}, name: String.to_atom(nombre)) do
            {:ok, _pid} ->
              GenServer.call({:global, Proyecto.Servidor}, {:connect, nombre, self()})
              send_resp(conn, 200, Jason.encode!(%{ok: true, usuario: nombre}))
            {:error, {:already_started, _}} ->
              GenServer.call({:global, Proyecto.Servidor}, {:connect, nombre, self()})
              send_resp(conn, 200, Jason.encode!(%{ok: true, usuario: nombre}))
            {:error, reason} ->
              send_resp(conn, 400, Jason.encode!(%{ok: false, error: inspect(reason)}))
          end
        else
          send_resp(conn, 401, Jason.encode!(%{ok: false, error: "Credenciales incorrectas"}))
        end
      _ ->
        if contenido_ets == [] do
          send_resp(conn, 401, Jason.encode!(%{ok: false, error: "No hay usuarios registrados. Debes registrar primero."}))
        else
          send_resp(conn, 401, Jason.encode!(%{ok: false, error: "Credenciales incorrectas"}))
        end
    end
  end

  # Listar usuarios conectados
  get "/usuarios" do
    {:ok, usuarios} = GenServer.call({:global, Proyecto.Servidor}, :listar_usuarios)
    send_resp(conn, 200, Jason.encode!(%{usuarios: usuarios}))
  end

  # Crear sala
  post "/sala" do
    %{"nombre" => nombre_sala} = conn.body_params
    case GenServer.call({:global, Proyecto.Servidor}, {:crear_sala, nombre_sala}) do
      :ok -> send_resp(conn, 201, Jason.encode!(%{ok: true}))
      {:error, reason} -> send_resp(conn, 400, Jason.encode!(%{ok: false, error: reason}))
    end
  end

  # Unirse a sala
  post "/sala/unirse" do
    %{"usuario" => usuario, "sala" => sala} = conn.body_params
    case GenServer.call({:global, Proyecto.Servidor}, {:entrar_sala, usuario, sala}) do
      :ok -> send_resp(conn, 200, Jason.encode!(%{ok: true}))
      {:error, reason} -> send_resp(conn, 400, Jason.encode!(%{ok: false, error: reason}))
    end
  end

  # Abandonar sala
  post "/sala/abandonar" do
    %{"usuario" => usuario} = conn.body_params
    case GenServer.call({:global, Proyecto.Servidor}, {:abandonar_sala, usuario}) do
      :ok -> send_resp(conn, 200, Jason.encode!(%{ok: true}))
      {:error, reason} -> send_resp(conn, 400, Jason.encode!(%{ok: false, error: reason}))
    end
  end

  # Historial de sala
  get "/sala/:nombre/historial" do
    {:ok, historial} = GenServer.call({:global, Proyecto.Servidor}, {:listar_historial, nombre})
    send_resp(conn, 200, Jason.encode!(%{historial: Enum.reverse(historial)}))
  end

  # Buscar mensajes
  get "/sala/:nombre/buscar" do
    palabra = conn.query_params["palabra"]
    {:ok, encontrados} = GenServer.call({:global, Proyecto.Servidor}, {:buscar_mensajes, nombre, palabra})
    send_resp(conn, 200, Jason.encode!(%{mensajes: Enum.reverse(encontrados)}))
  end

  # Enviar mensaje
  post "/mensaje" do
    %{"usuario" => usuario, "sala" => sala, "mensaje" => mensaje} = conn.body_params
    GenServer.cast({:global, Proyecto.Servidor}, {:enviar_mensaje, usuario, sala, mensaje})
    send_resp(conn, 202, Jason.encode!(%{ok: true}))
  end

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Path.expand("../../frontend/index.html", __DIR__))
  end

  match _ do
    IO.inspect({conn.method, conn.request_path, conn.body_params}, label: "NO MATCH ROUTE")
    send_resp(conn, 404, Jason.encode!(%{error: "No encontrado"}))
  end
end

defmodule Proyecto.ETSContrasenas do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    if :ets.whereis(:proyecto_contraseñas) == :undefined do
      :ets.new(:proyecto_contraseñas, [:named_table, :set, :public])
    end
    {:ok, nil}
  end
end

defmodule ProyectoWebServer do
  def start do
    # Inicia el proceso que mantiene viva la tabla ETS antes de Plug.Cowboy
    Proyecto.ContrasenaStorage.start_link([])
    Plug.Cowboy.http Proyecto.API, [], port: 4000
  end
end

# Para iniciar el servidor web, llama a ProyectoWebServer.start/0 desde tu aplicación principal.
