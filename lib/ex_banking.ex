defmodule ExBanking do
  @moduledoc """
  Documentation for ExBanking.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ExBanking.hello()
      :world

  """

  @type banking_error ::
          {:error,
           :wrong_arguments
           | :user_already_exists
           | :user_does_not_exist
           | :not_enough_money
           | :sender_does_not_exist
           | :receiver_does_not_exist
           | :too_many_requests_to_user
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  @spec create_user(user :: String.t()) :: :ok | banking_error
  defdelegate create_user(user), to: ExBanking.User.DynamicSupervisor

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  defdelegate deposit(user, amount, currency), to: ExBanking.User

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  defdelegate withdraw(user, amount, currency), to: ExBanking.User

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number} | banking_error
  defdelegate get_balance(user, currency), to: ExBanking.User

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  defdelegate send(from_user, to_user, amount, currency), to: ExBanking.User
end
