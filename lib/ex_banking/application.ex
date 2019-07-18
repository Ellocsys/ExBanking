defmodule ExBanking.Application do
  use Application

  def start(_, _) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: ExBanking.User.DynamicSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
