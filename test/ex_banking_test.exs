defmodule ExBankingTest do
  use ExUnit.Case

  def clear_users(_context) do
    ExBanking.User.DynamicSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {:undefined, pid, _type, _sup} ->
      IO.inspect(pid)
      DynamicSupervisor.terminate_child(ExBanking.User.DynamicSupervisor, pid)
    end)

    :ok
  end

  # setup :clear_users

  describe "ExBanking.create_user/1" do
    setup do
      %{username: "Igor"}
    end

    test "", %{username: username} do
      assert ExBanking.create_user(username) == :ok

      assert %{active: 1, specs: 1, supervisors: 0, workers: 1} ==
               ExBanking.User.DynamicSupervisor |> DynamicSupervisor.count_children()
    end

    test "with wrong argument" do
      assert {:error, :wrong_arguments} == ExBanking.create_user(1)
    end

    test "try create same user twice", %{username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:error, :user_already_exists} == ExBanking.create_user(username)
    end
  end

  describe "ExBanking.get_balance/1" do
    setup do
      %{username: "Igor", currency: "$"}
    end

    test "", %{username: username, currency: currency} do
      assert :ok == ExBanking.create_user(username)
      assert 0 == ExBanking.get_balance(username, currency)
    end

    test "for not existing user", %{username: username, currency: currency} do
      assert {:error, :user_does_not_exist} == ExBanking.get_balance(username, currency)
    end

    test "with wrong arguments" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance(1, {})
    end
  end

  describe "ExBanking.deposit/3" do
    setup do
      %{
        username: "Igor",
        integer_amount: 22,
        float_amount: 100.111,
        two_precision_float: 33.22,
        currency: "$"
      }
    end

    test "", %{username: username, amount: amount, currency: currency} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, amount |> Float.round(2)} == ExBanking.deposit(username, amount, currency)
      assert {:ok, amount |> Float.round(2)} == ExBanking.get_balance(username, currency)
    end

    # test "", %{username: username, amount: amount, currency: currency} do
    #   assert ExBanking.create_user(username) == :ok

    #   assert ExBanking.deposit(username, amount |> Float.round(), currency) ==
    #            {:ok, amount |> Float.round()}

    #   assert ExBanking.deposit(username, amount |> Float.round(), currency) ==
    #            {:ok, amount |> Float.round(2)}

    #   assert ExBanking.get_balance(username, currency) == amount |> Float.round(2)
    # end

    test "to not existing user", %{username: username, amount: amount, currency: currency} do
      assert {:error, :user_does_not_exist} == ExBanking.deposit(username, amount, currency)
    end

    test "with wrong argument" do
      assert {:error, :wrong_arguments} == ExBanking.deposit(1, [], {})
    end

    test "with zero amount", %{username: username, currency: currency} do
      assert {:error, :wrong_arguments} == ExBanking.deposit(username, 0, currency)
    end
  end

  describe "ExBanking.withdraw/3" do
    setup do
      %{username: "Igor", amount: 100, currency: "$"}
    end

    test "", %{username: username, amount: amount, currency: currency} do
      assert ExBanking.create_user(username) == :ok
      assert ExBanking.deposit(username, amount, currency) == {:ok, amount}
      assert ExBanking.withdraw(username, amount, currency) == {:ok, 0}
    end

    test "with issuficient balance", %{username: username, amount: amount, currency: currency} do
      assert ExBanking.create_user(username) == :ok
      assert ExBanking.withdraw(username, amount, currency) == {:error, :not_enough_money}
    end

    test "from not existing user", %{username: username, amount: amount, currency: currency} do
      assert ExBanking.withdraw(username, amount, currency) == {:error, :wrong_arguments}
    end

    test "with wrong argument" do
      assert ExBanking.withdraw(1, [], {}) == {:error, :wrong_arguments}
    end

    test "with zero amount", %{username: username, currency: currency} do
      assert ExBanking.withdraw(username, 0, currency) == {:error, :wrong_arguments}
    end
  end

  describe "ExBanking.send/4" do
    setup do
      %{to_user: "Igor", from_user: "AnotherIgor", amount: 100, currency: "$"}
    end

    test "", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok
      assert ExBanking.create_user(to_user) == :ok

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}
      assert ExBanking.send(from_user, to_user, amount, currency) == {:ok, 0, amount}

      assert ExBanking.get_balance(to_user, currency) == amount
      assert ExBanking.get_balance(from_user, currency) == 0
    end

    test "to not exisitig user", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert ExBanking.create_user(from_user) == :ok

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}

      assert ExBanking.send(from_user, to_user, amount, currency) ==
               {:error, :receiver_does_not_exist}

      assert ExBanking.get_balance(from_user, currency) == amount
    end

    test "from not exisiting user", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert ExBanking.create_user(to_user) == :ok

      assert ExBanking.send(from_user, to_user, amount, currency) ==
               {:error, :sender_does_not_exist}

      assert ExBanking.get_balance(to_user, currency) == amount
    end

    test "both user not exist", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert ExBanking.send(from_user, to_user, amount, currency) == {:error, :wrong_arguments}
    end

    test "yourself", %{from_user: from_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}

      assert ExBanking.send(from_user, from_user, amount, currency) == {:error, :wrong_arguments}
    end

    test "from user with issuficient balance", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert ExBanking.create_user(from_user) == :ok
      assert ExBanking.create_user(to_user) == :ok

      assert ExBanking.send(from_user, to_user, amount, currency) == {:error, :not_enough_money}

      assert ExBanking.get_balance(from_user, currency) == amount
      assert ExBanking.get_balance(to_user, currency) == 0
    end

    test "with negative amount", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert ExBanking.create_user(from_user) == :ok
      assert ExBanking.create_user(to_user) == :ok

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}
      assert ExBanking.send(from_user, to_user, amount, currency) == {:error, :wrong_arguments}

      assert ExBanking.get_balance(from_user, currency) == amount
      assert ExBanking.get_balance(to_user, currency) == 0
    end
  end

  describe "Check backpressure" do
    setup do
      %{to_user: "Igor", from_user: "AnotherIgor", amount: 100, currency: "$"}
    end

    test "for ExBanking.create_user/1", %{to_user: to_user} do
      for _ <- 0..9,
          do: Task.async(fn -> {to_user, ExBanking.create_user(to_user)} end)

      assert {:error, :too_many_requests_to_user} == ExBanking.create_user(to_user)
    end

    test "for ExBanking.deposit/2", %{from_user: from_user, amount: amount, currency: currency} do
      assert :ok == ExBanking.create_user(from_user)

      for _ <- 0..9,
          do: Task.async(fn -> {from_user, ExBanking.deposit(from_user, amount, currency)} end)

      assert {:error, :too_many_requests_to_user} == ExBanking.deposit(from_user, amount, currency) == {:ok, amount}
    end

    test "for sender", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert :ok == ExBanking.create_user(from_user)
      assert :ok == ExBanking.create_user(to_user)

      for _ <- 0..9,
          do: Task.async(fn -> {from_user, ExBanking.deposit(from_user, amount, currency)} end)

      assert {:error, :too_many_requests_to_sender} == ExBanking.send(from_user, to_user, amount, currency)
    end

    test "for receiver", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert :ok == ExBanking.create_user(from_user)
      assert :ok == ExBanking.create_user(to_user)


      ExBanking.deposit(from_user, amount, currency)

      for _ <- 0..9,
          do: Task.async(fn -> {to_user, ExBanking.deposit(to_user, amount, currency)} end)

      assert  {:error, :too_many_requests_to_receiver} == ExBanking.send(from_user, to_user, amount, currency)
    end
  end
end
