defmodule ExBanking.User do
  use GenServer

  def create_user(user),
    do: ExBanking.User.DynamicSupervisor.create_user(user)

  def get_balance(user, currency),
    do: GenServer.call(name(user), {:get_balance, currency})

  def deposit(user, amount, currency),
    do: GenServer.call(name(user), {:deposit, amount, currency})

  def withdraw(user, amount, currency),
    do: GenServer.call(name(user), {:withdraw, amount, currency})

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
    deposit = Decimal.cast(amount) |> Decimal.round(2)

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
    withdraw_amount = amount |> Decimal.cast() |> Decimal.round(2)
    current_balance = state |> Map.get(:accounts) |> Map.get(currency, Decimal.new(0))

    case Decimal.cmp(current_balance, withdraw_amount) do
      :lt ->
        {:reply, {:error, :not_enough_money}, state}

      _ ->
        new_state =
          put_in(state, [:accounts, currency], Decimal.sub(current_balance, withdraw_amount))

        new_balance = new_state[:accounts][currency] |> Decimal.to_float()

        {:reply, {:ok, new_balance}, new_state}
    end
  end
end
