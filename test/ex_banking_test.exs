defmodule ExBankingTest do
  use ExUnit.Case

  describe "ExBanking.create_user/1" do
    setup do
      %{username: "Igor"}
    end

    test "", %{username: username} do
      assert ExBanking.create_user(username) == :ok
    end

    test "with wrong argument" do
      assert ExBanking.create_user(1) == {:error, :wrong_argument}
    end

    test "try create same user twice", %{username: username} do
      assert ExBanking.create_user(username) == :ok
      assert ExBanking.create_user(username) == {:error, :user_already_exist}
    end
  end

  describe "ExBanking.get_balance/1" do
    setup do
      %{username: "Igor", currency: "$"}
    end

    test "", %{username: username, currency: currency} do
      assert ExBanking.create_user(username) == :ok
      assert ExBanking.get_balance(username, currency) == 0
    end

    test "for not existing user", %{username: username, currency: currency} do
      assert ExBanking.get_balance(username, currency) == {:error, :user_does_not_exist}
    end

    test "with wrong arguments" do
      assert ExBanking.get_balance(1, {}) == {:error, :wrong_argument}
    end
  end

  describe "ExBanking.deposit/3" do
    setup do
      %{username: "Igor", amount: 100, currency: "$"}
    end

    test "", %{username: username, amount: amount, currency: currency} do
      assert ExBanking.create_user(username) == :ok
      assert ExBanking.deposit(username, amount, currency) == {:ok, amount}
      assert ExBanking.get_balance(username, currency) == amount
    end

    test "to not existing user", %{username: username, amount: amount, currency: currency} do
      assert ExBanking.deposit(username, amount, currency) == {:error, :user_does_not_exist}
    end

    test "with wrong argument" do
      assert ExBanking.deposit(1, [], {}) == {:error, :wrong_argument}
    end

    test "with zero amount", %{username: username, currency: currency} do
      assert ExBanking.deposit(username, 0, currency) == {:error, :wrong_argument}
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
      assert ExBanking.withdraw(username, amount, currency) == {:error, :wrong_argument}
    end

    test "with wrong argument" do
      assert ExBanking.withdraw(1, [], {}) == {:error, :wrong_argument}
    end

    test "with zero amount", %{username: username, currency: currency}  do
      assert ExBanking.withdraw(username, 0, currency) == {:error, :wrong_argument}
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

    test "to not exisitig user", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}
      assert ExBanking.send(from_user, to_user, amount, currency) == {:error, :receiver_does_not_exist}

      assert ExBanking.get_balance(from_user, currency) == amount
    end

    test "from not exisiting user", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(to_user) == :ok

      assert ExBanking.send(from_user, to_user, amount, currency) == {:error, :sender_does_not_exist}

      assert ExBanking.get_balance(to_user, currency) == amount
    end

    test "both user not exist", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.send(from_user, to_user, amount, currency) == {:error, :wrong_argument}
    end

    test "yourself", %{from_user: from_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}

      assert ExBanking.send(from_user, from_user, amount, currency) == {:error, :wrong_argument}
    end

    test "from user with issuficient balance", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok
      assert ExBanking.create_user(to_user) == :ok

      assert ExBanking.send(from_user, to_user, amount, currency) == {:error, :not_enough_money}

      assert ExBanking.get_balance(from_user, currency) == amount
      assert ExBanking.get_balance(to_user, currency) == 0
    end

    test "with negative amount", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
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

    test "for user", %{from_user: from_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok
      for _ <- 0..9, do: Task.async(fn -> {from_user, ExBanking.deposit(from_user, amount, currency)} end)
      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount} == {:error, :too_many_requests_to_user}
    end

    test "for sender", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok
      assert ExBanking.create_user(to_user) == :ok

      for _ <- 0..9, do: Task.async(fn -> {from_user, ExBanking.deposit(from_user, amount, currency)} end)

      assert ExBanking.send(from_user, to_user, amount, currency)  == {:error, :too_many_requests_to_sender}
    end

    test "for receiver", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.create_user(from_user) == :ok
      assert ExBanking.create_user(to_user) == :ok

      ExBanking.deposit(from_user, amount, currency)

      for _ <- 0..9, do: Task.async(fn -> {to_user, ExBanking.deposit(to_user, amount, currency)} end)

      assert ExBanking.send(from_user, to_user, amount, currency)  == {:error, :too_many_requests_to_receiver}
    end
  end
end
