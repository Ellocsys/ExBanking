defmodule ExBankingTest do
  use ExUnit.Case

  def clear_users(_context) do
    ExBanking.User.DynamicSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {:undefined, pid, _type, _sup} ->
      DynamicSupervisor.terminate_child(ExBanking.User.DynamicSupervisor, pid)
    end)

    Process.sleep(1)

    :ok
  end

  setup [:clear_users]

  describe "ExBanking.create_user/1" do
    setup do
      %{user: "Igor"}
    end

    test "", %{user: user} do
      assert ExBanking.create_user(user) == :ok

      assert %{active: 1, specs: 1, supervisors: 0, workers: 1} ==
               ExBanking.User.DynamicSupervisor |> DynamicSupervisor.count_children()
    end

    test "with wrong argument" do
      assert {:error, :wrong_arguments} == ExBanking.create_user(1)
    end

    test "try create same user twice", %{user: user} do
      assert :ok == ExBanking.create_user(user)
      assert {:error, :user_already_exists} == ExBanking.create_user(user)
    end
  end

  describe "ExBanking.get_balance/1" do
    setup do
      %{user: "Igor", currency: "$"}
    end

    test "", %{user: user, currency: currency} do
      assert :ok == ExBanking.create_user(user)
      assert {:ok, 0} == ExBanking.get_balance(user, currency)
    end

    test "for not existing user", %{user: user, currency: currency} do
      assert {:error, :user_does_not_exist} == ExBanking.get_balance(user, currency)
    end

    test "with wrong arguments", %{user: user} do
      assert :ok == ExBanking.create_user(user)
      assert {:error, :wrong_arguments} == ExBanking.get_balance(user, {})
    end
  end

  describe "ExBanking.deposit/3" do
    setup do
      %{
        user: "Igor",
        integer_amount: 22,
        float_amount: 100.111,
        two_precision_float: 33.22,
        currency: "$"
      }
    end

    @tag :fuck
    test "", %{user: user, float_amount: float_amount, currency: currency} do
      assert :ok == ExBanking.create_user(user)

      assert {:ok, Float.round(float_amount, 2)} ==
               ExBanking.deposit(user, float_amount, currency)

      assert {:ok, Float.round(float_amount, 2)} == ExBanking.get_balance(user, currency)
    end

    # test "", %{user: user, amount: amount, currency: currency} do
    #   assert ExBanking.create_user(user) == :ok

    #   assert ExBanking.deposit(user, amount |> Float.round(), currency) ==
    #            {:ok, amount |> Float.round()}

    #   assert ExBanking.deposit(user, amount |> Float.round(), currency) ==
    #            {:ok, amount |> Float.round(2)}

    #   assert ExBanking.get_balance(user, currency) == amount |> Float.round(2)
    # end

    test "to not existing user", %{user: user, float_amount: amount, currency: currency} do
      assert {:error, :user_does_not_exist} == ExBanking.deposit(user, amount, currency)
    end

    test "with wrong argument" do
      assert {:error, :wrong_arguments} == ExBanking.deposit(1, [], {})
    end

    test "with zero amount", %{user: user, currency: currency} do
      assert {:error, :wrong_arguments} == ExBanking.deposit(user, 0, currency)
    end
  end

  describe "ExBanking.withdraw/3" do
    setup do
      %{user: "Igor", amount: 100, currency: "$"}
    end

    @tag :fuck
    test "", %{user: user, amount: amount, currency: currency} do
      assert :ok == ExBanking.create_user(user)

      assert {:ok, amount} == ExBanking.deposit(user, amount, currency)
      assert {:ok, 0} == ExBanking.withdraw(user, amount, currency)
    end

    test "with issuficient balance", %{user: user, amount: amount, currency: currency} do
      assert :ok == ExBanking.create_user(user)
      assert {:error, :not_enough_money} == ExBanking.withdraw(user, amount, currency)
    end

    test "from not existing user", %{user: user, amount: amount, currency: currency} do
      assert {:error, :user_does_not_exist} == ExBanking.withdraw(user, amount, currency)
    end

    test "with wrong argument" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw(1, [], {})
    end

    test "with zero amount", %{user: user, currency: currency} do
      assert {:error, :wrong_arguments} == ExBanking.withdraw(user, 0, currency)
    end
  end

  describe "ExBanking.send/4" do
    setup do
      %{to_user: "Igor", from_user: "AnotherIgor", amount: 100, currency: "$"}
    end

    test "", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert :ok == ExBanking.create_user(from_user)
      assert :ok == ExBanking.create_user(to_user)

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}
      assert ExBanking.send(from_user, to_user, amount, currency) == {:ok, 0, amount}

      assert ExBanking.get_balance(to_user, currency) == {:ok, amount}
      assert ExBanking.get_balance(from_user, currency) == {:ok, 0}
    end

    test "to not exisitig user", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert :ok == ExBanking.create_user(from_user)

      assert ExBanking.deposit(from_user, amount, currency) == {:ok, amount}

      assert ExBanking.send(from_user, to_user, amount, currency) ==
               {:error, :receiver_does_not_exist}

      assert ExBanking.get_balance(from_user, currency) == {:ok, amount}
    end

    test "from not exisiting user", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert :ok == ExBanking.create_user(to_user)

      assert {:error, :sender_does_not_exist} ==
               ExBanking.send(from_user, to_user, amount, currency)

      assert {:ok, 0} == ExBanking.get_balance(to_user, currency)
    end

    test "both user not exist", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert {:error, :sender_does_not_exist} ==
               ExBanking.send(from_user, to_user, amount, currency)
    end

    test "yourself", %{from_user: from_user, amount: amount, currency: currency} do
      assert :ok == ExBanking.create_user(from_user)

      assert {:ok, amount} == ExBanking.deposit(from_user, amount, currency)

      assert {:error, :wrong_arguments} == ExBanking.send(from_user, from_user, amount, currency)
    end

    test "from user with issuficient balance", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert :ok == ExBanking.create_user(from_user)
      assert :ok == ExBanking.create_user(to_user)

      assert {:error, :not_enough_money} = ExBanking.send(from_user, to_user, amount, currency)

      assert {:ok, 0} == ExBanking.get_balance(from_user, currency)
      assert {:ok, 0} == ExBanking.get_balance(to_user, currency)
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

      assert ExBanking.send(from_user, to_user, -1 * amount, currency) ==
               {:error, :wrong_arguments}

      assert ExBanking.get_balance(from_user, currency) == {:ok, amount}
      assert ExBanking.get_balance(to_user, currency) == {:ok, 0}
    end
  end

  describe "Check backpressure" do
    setup do
      %{to_user: "Igor", from_user: "AnotherIgor", amount: 100, currency: "$"}
    end

    test "for ExBanking.deposit/2", %{from_user: from_user, amount: amount, currency: currency} do
      assert :ok == ExBanking.create_user(from_user)

      [{pid, _}] = ExBanking.User.lookup(from_user)
      :sys.suspend(pid)

      tasks =
        for _ <- 0..50,
            do: Task.async(fn -> {from_user, ExBanking.deposit(from_user, amount, currency)} end)

      :sys.resume(pid)

      assert {:error, :too_many_requests_to_user} ==
               ExBanking.deposit(from_user, amount, currency)

      tasks
      |> Enum.map(&Task.await/1)
    end

    test "for sender", %{
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    } do
      assert :ok == ExBanking.create_user(from_user)
      assert :ok == ExBanking.create_user(to_user)

      [{pid, _}] = ExBanking.User.lookup(from_user)
      :sys.suspend(pid)

      tasks =
        for _ <- 0..50,
            do: Task.async(fn -> {from_user, ExBanking.deposit(from_user, amount, currency)} end)

      :sys.resume(pid)

      assert {:error, :too_many_requests_to_sender} ==
               ExBanking.send(from_user, to_user, amount, currency)

      tasks
      |> Enum.map(&Task.await/1)
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

      [{pid, _}] = ExBanking.User.lookup(to_user)
      :sys.suspend(pid)

      tasks =
        for _ <- 0..50,
            do: Task.async(fn -> {to_user, ExBanking.deposit(to_user, amount, currency)} end)

      :sys.resume(pid)

      assert {:error, :too_many_requests_to_receiver} ==
               ExBanking.send(from_user, to_user, amount, currency)

      tasks
      |> Enum.map(&Task.await/1)
    end
  end
end
