defmodule ExBanking.User do
  use GenServer

  @operations_limit 10

  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    if alive?(user) do
      GenServer.call(name(user), [:user_get_balance, currency])
    else
      {:error, :user_does_not_exist}
    end
  end

  def get_balance(_user, _amount), do: {:error, :wrong_arguments}

  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and amount > 0 and is_binary(currency) do
    if alive?(user) do
      GenServer.call(name(user), [:user_deposit, amount, currency])
    else
      {:error, :user_does_not_exist}
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and amount > 0 and is_binary(currency) do
    if alive?(user) do
      GenServer.call(name(user), [:user_withdraw, amount, currency])
    else
      {:error, :user_does_not_exist}
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_number(amount) and amount > 0 and
             is_binary(currency) and from_user != to_user do
    with {[{from_user_pid, _meta}], _from_user} <- {lookup(from_user), from_user},
         {false, _from_user} <- {queeue_overlimit?(from_user_pid), from_user},
         {[{to_user_pid, _meta}], _to_user} <- {lookup(to_user), to_user},
         {false, _from_user} <- {queeue_overlimit?(to_user_pid), to_user},
         {:ok, from_user_balance} <-
           GenServer.call(name(from_user), [:user_withdraw, amount, currency]),
         {:ok, to_user_balance} <-
           GenServer.call(name(to_user), [:user_deposit, amount, currency]) do
      {:ok, from_user_balance, to_user_balance}
    else
      {true, ^from_user} -> {:error, :too_many_requests_to_sender}
      {[], ^from_user} -> {:error, :sender_does_not_exist}
      {true, ^to_user} -> {:error, :too_many_requests_to_receiver}
      {[], ^to_user} -> {:error, :receiver_does_not_exist}
      {:error, _msg} = error_msg -> error_msg
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  defp alive?(user),
    do: [] != lookup(user)

  defp lookup(user),
    do: Registry.lookup(ExBanking.User.Registry, user)

  defp name(user), do: {:via, Registry, {ExBanking.User.Registry, user}}

  def start_link(user) do
    GenServer.start_link(__MODULE__, [], name: name(user))
  end

  def init(_) do
    state = %{accounts: %{}}

    {:ok, state}
  end

  def handle_call([action | args], _from, state) do
    if queeue_overlimit?(self()) do
      {:reply, {:error, :too_many_requests_to_user}, state}
    else
      apply(__MODULE__, action, [state | args])
      |> Tuple.insert_at(0, :reply)
    end
  end

  defp queeue_overlimit?(pid) do
    pid
    |> Process.info()
    |> Keyword.fetch!(:message_queue_len)
    |> Kernel.>=(@operations_limit)
  end

  def user_get_balance(state, currency) do
    balance =
      state
      |> get_in([:accounts, currency])
      |> case do
        nil -> 0
        balance -> balance |> Decimal.to_float()
      end

    {{:ok, balance}, state}
  end

  def user_deposit(state, amount, currency) do
    deposit = Decimal.cast(amount) |> Decimal.round(2)

    new_state =
      state
      |> update_in([:accounts, currency], fn
        nil -> deposit
        current_balance -> Decimal.add(deposit, current_balance)
      end)

    new_balance = new_state |> get_in([:accounts, currency]) |> Decimal.to_float()

    {{:ok, new_balance}, new_state}
  end

  def user_withdraw(state, amount, currency) do
    withdraw_amount = amount |> Decimal.cast() |> Decimal.round(2)
    current_balance = state |> Map.get(:accounts) |> Map.get(currency, Decimal.new(0))

    case Decimal.cmp(current_balance, withdraw_amount) do
      :lt ->
        {{:error, :not_enough_money}, state}

      _ ->
        new_state =
          put_in(state, [:accounts, currency], Decimal.sub(current_balance, withdraw_amount))

        new_balance = new_state[:accounts][currency] |> Decimal.to_float()

        {{:ok, new_balance}, new_state}
    end
  end
end
