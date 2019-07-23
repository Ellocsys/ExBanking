defmodule ExBanking.Application do
  use Application

  def start(_, _) do
    children = [
      {Registry, name: ExBanking.User.Registry, keys: :unique},
      ExBanking.User.DynamicSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
