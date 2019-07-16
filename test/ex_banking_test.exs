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
      %{username: "Igor", amount: Decimal.new(100), currency: "$"}
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
  end

  describe "ExBanking.withdraw/3" do
    setup do
      %{username: "Igor", amount: 100, currency: "$"}
    end
    
    test "", %{username: username, amount: amount, currency: currency} do
      assert ExBanking.create_user(username) == :ok
      assert ExBanking.deposit(username, amount, currency) == {:ok, amount}
      assert ExBanking.withdraw(username, amount, currency) == {:ok, Decimal.new(0)}
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
  end

  describe "ExBanking.send/4" do
    setup do
      %{to_user: "Igor", from_user: "Igor", amount: 100, currency: "$"}
    end
    
    test "", %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} do
      assert ExBanking.send(from_user, to_user, amount, currency) == {:ok, Decimal.new(0), Decimal.new(0)}
    end   
  end
end
