defmodule ExBanking.Application do
  use Application

  def start(_, _) do
    children = [
      {Registry, name: ExBanking.User.Registry, keys: :unique},
      {Task.Supervisor, name: ExBanking.Dispatcher.TaskSupervisor},
      ExBanking.Dispatcher,
      ExBanking.User.DynamicSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
