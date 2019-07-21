defmodule ExBanking.User do
  use GenServer

  def create_user(user),
    do: ExBanking.User.DynamicSupervisor.create_user(user)

  def get_balance(user, currency) when is_binary(user) and is_binary(currency),
    do: GenServer.call(__MODULE__, {:get_balance, user, currency})

  def get_balance(_user, _amount), do: {:error, :wrong_arguments}

  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and amount >= 0 and is_binary(currency),
      do: GenServer.call(__MODULE__, {:deposit, user, amount, currency})

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and amount >= 0 and is_binary(currency),
      do: GenServer.call(__MODULE__, {:withdraw, user, amount, currency})

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def lookup(user),
    do: Registry.lookup(ExBanking.User.Registry, user)

  def name(user), do: {:via, Registry, {ExBanking.User.Registry, user}}

  def start_link(user) do
    GenServer.start_link(__MODULE__, [], name: name(user))
  end

  def init(_) do
    state = %{accounts: %{}}

    {:ok, state}
  end

  def handle_call({:get_balance, currency}, _from, state) do
    balance =
      state
      |> get_in([:accounts, currency])
      |> case do
        nil -> 0
        balance -> balance |> Decimal.to_float()
      end

    {:reply, {:ok, balance}, state}
  end

  def handle_call({:deposit, amount, currency}, _from, state) do
    Decimal.set_context(precision: 2)
    deposit = Decimal.cast(amount)

    new_state =
      state
      |> update_in([:accounts, currency], fn
        nil -> deposit
        current_balance -> Decimal.add(deposit, current_balance)
      end)

    new_balance = new_state |> get_in([:accounts, currency]) |> Decimal.to_float()

    {:reply, {:ok, new_balance}, new_state}
  end

  def handle_call({:withdraw, amount, currency}, _from, state) do
    Decimal.set_context(precision: 2)
    withdraw_amount = amount |> Decimal.cast()
    current_balance = state |> Map.get(:accounts) |> Map.get(currency, Decimal.new(0))

    case Decimal.cmp(current_balance, withdraw_amount) do
      :lt ->
        {:reply, {:error, :not_enough_money}, state}

      _ ->
        new_state =
          put_in(state, [:account, currency], Decimal.sub(current_balance, withdraw_amount))

        new_balance = new_state[:account][currency] |> Decimal.to_float()

        {:reply, {:ok, new_balance}, new_state}
    end
  end
end
