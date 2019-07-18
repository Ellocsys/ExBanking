defmodule ExBanking.User do
  use GenStage

  def start_link(init) do
    GenStage.start_link(__MODULE__, init, name: __MODULE__)
  end

  def init(_) do
    state = %{accounts: %{}}
    {:ok, state}
  end

  def handle_demand(demand, state) do
    events = Enum.to_list(state..(state + demand - 1))
    {:noreply, events, state + demand}
  end
end
