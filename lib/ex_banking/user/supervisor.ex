defmodule ExBanking.User.DynamicSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Create user function. 
  Verify that the username valid 
  And creates a user process if it can
  """
  def create_user(user) when is_binary(user) do
    DynamicSupervisor.start_child(__MODULE__, {ExBanking.User, user})
    |> case do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :user_already_exists}
      {:error, error} -> {:error, error}
    end
  end

  def create_user(_user), do: {:error, :wrong_arguments}
end
