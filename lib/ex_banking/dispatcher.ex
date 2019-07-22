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

  def create_user(user) when is_binary(user),
    do: GenServer.call(__MODULE__, {:create_user, [user]})

  def create_user(_user), do: {:error, :wrong_arguments}

  def get_balance(user, currency) when is_binary(user) and is_binary(currency),
    do: GenServer.call(__MODULE__, {:get_balance, [user, currency]})

  def get_balance(_user, _amount), do: {:error, :wrong_arguments}

  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and amount > 0 and is_binary(currency),
      do: GenServer.call(__MODULE__, {:withdraw, [user, amount, currency]})

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and amount > 0 and is_binary(currency),
      do: GenServer.call(__MODULE__, {:deposit, [user, amount, currency]})

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_number(amount) and amount > 0 and
             is_binary(currency) and from_user != to_user,
      do: GenServer.call(__MODULE__, {:send, [from_user, to_user, amount, currency]})

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    state = %{task_refs: []}

    {:ok, state}
  end

  def handle_call({:send, [from_user, to_user, amount, currency]}, _from, state) do
    with {:ok, sender_msg} <- dispatch({:withdraw, [from_user, amount, currency]}, state),
         {:ok, receiver_msg} <- dispatch({:deposit, [to_user, amount, currency]}, state),
         {:ok, from_user_balance} <- sync_call(sender_msg),
         {:ok, to_user_balance} <- sync_call(receiver_msg) do
      {:reply, {:ok, from_user_balance, to_user_balance}, state}
    else
      {{:error, :too_many_requests_to_user}, ^from_user} ->
        {:reply, {:error, :too_many_requests_to_sender}, state}

      {{:error, :too_many_requests_to_user}, ^to_user} ->
        {:reply, {:error, :too_many_requests_to_receiver}, state}

      {{:error, :user_does_not_exist}, ^from_user} ->
        {:reply, {:error, :sender_does_not_exist}, state}

      {{:error, :user_does_not_exist}, ^to_user} ->
        {:reply, {:error, :receiver_does_not_exist}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(msg, from, state) do
    dispatch(msg, state)
    |> async_call(from, state)
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

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp dispatch({operation, [user | _tail]} = msg, %{task_refs: task_refs}) do
    if User.lookup(user) == [] and operation != :create_user do
      {{:error, :user_does_not_exist}, user}
    else
      task_refs
      |> IO.inspect()

      task_refs
      |> Enum.filter(fn {ref_user, _, _} -> ref_user == user end)
      |> case do
        # One more thing is not straightforward: is a create_user/1 an operation on a user?
        # if we call 11 times a create_user/1, should we returne :too_many_requests_to_user?
        list when is_list(list) and length(list) > @operations_limit ->
          {{:error, :too_many_requests_to_user}, user}

        list when is_list(list) ->
          {:ok, msg}
      end
    end
  end

  defp async_call({:ok, {operation, [user | _] = args}}, from, %{task_refs: task_refs} = state) do
    %{ref: ref} = Task.Supervisor.async_nolink(TaskSupervisor, User, operation, args)
    {:noreply, %{state | task_refs: [{user, ref, from} | task_refs]}}
  end

  defp async_call({error, _user}, _from, state) do
    {:reply, error, state}
  end

  defp sync_call({:ok, {operation, args}}),
    do: apply(User, operation, args)

  defp sync_call(error),
    do: error
end
