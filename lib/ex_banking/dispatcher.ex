defmodule ExBanking.Dispatcher do
  use GenServer

  alias ExBanking.User
  alias ExBanking.Dispatcher.TaskSupervisor

  require Logger

  @operations_limit 10

  # There is some ambiguity with the condition: 
  # Should calls with incorrect parameters (:wrong_argument) be counted as operations? 
  # It should have been clarified, but I am doing this task on the weekend 
  # and it’s unlikely that someone will answer my question.
  # So, I will assume that it should

  def create_user(user),
    do: GenServer.call(__MODULE__, {:create_user, [user]})

  def get_balance(user, currency),
    do: GenServer.call(__MODULE__, {:get_balance, [user, currency]})

  def withdraw(user, amount, currency),
    do: GenServer.call(__MODULE__, {:withdraw, [user, amount, currency]})

  def deposit(user, amount, currency),
    do: GenServer.call(__MODULE__, {:deposit, [user, amount, currency]})

  def send(from_user, to_user, amount, currency),
    do: GenServer.call(__MODULE__, {:send, [from_user, to_user, amount, currency]})

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    state = %{task_refs: []}
    {:ok, state}
  end

  def handle_call({operation, [username | _tail] = args}, from, %{task_refs: task_refs} = state) do
    task_refs
    |> Enum.find(fn {user, _, _} -> user == username end)
    |> case do
      # One more thing is not straightforward: is a create_user/1 an operation on a user?
      # if we call 11 times a create_user/1, should we returne :too_many_requests_to_user?
      list when is_list(list) and length(list) > @operations_limit ->
        {:reply, :too_many_requests_to_user, state}

      _list ->
        task = Task.Supervisor.async_nolink(TaskSupervisor, User, operation, args)

        {:noreply, %{state | task_refs: [{username, task.ref, from} | task_refs]}}
    end
  end

  def handle_info({task_ref, result}, %{task_refs: task_refs} = state) do
    task_refs
    |> Enum.find(fn {_, ref, _} -> ref == task_ref end)
    |> case do
      nil ->
        Logger.warn(
          "Unknown task #{inspect(task_ref)} with result #{inspect(result)} received in module #{
            __MODULE__
          }"
        )

      {_user, _ref, caller} ->
        GenServer.reply(caller, result)
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, task_ref, :process, _pid, _reason}, %{task_refs: task_refs} = state) do
    new_refs =
      task_refs
      |> Enum.reject(fn {_, ref, _} -> ref == task_ref end)

    {:noreply, %{state | task_refs: new_refs}}
  end

  def hanle_info(message, state) do
    Logger.warn("Unknown message received in module #{__MODULE__}: #{inspect(message)} ")
    {:noreply, state}
  end
end
