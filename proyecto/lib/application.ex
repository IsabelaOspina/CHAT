#  defmodule Proyecto.Application do
#   use Application

#   def start(_type, _args) do
#     children = [
#       {Registry, keys: :unique, name: Proyecto.Registry},
#       Proyecto.Servidor
#     ]
#     opts = [strategy: :one_for_one, name: Proyecto.Supervisor]
#     Supervisor.start_link(children, opts)
#   end
# end
defmodule Proyecto.Application do
  use Application

  def start(_type, _args) do
    children = [
      Proyecto.Servidor,
        Proyecto.ContrasenaStorage,
      {Plug.Cowboy, scheme: :http, plug: Proyecto.API,options: [
        ip: {0, 0, 0, 0},   # 👈 Escucha en todas las interfaces
        port: 4000
      ]}

    ]

    opts = [strategy: :one_for_one, name: Proyecto.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
