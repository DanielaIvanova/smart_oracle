defmodule SmartOracle do
  @moduledoc """
  Documentation for SmartOracle.
  """

  alias Core.Client
  use GenServer

  def start_link([%Client{} = client, query_format, response_format, ttl, query_fee, []]) do
    GenServer.start(
      __MODULE__,
      [%Client{} = client, query_format, response_format, ttl, query_fee],
      name: __MODULE__
    )
  end

  def start_link([%Client{} = client, query_format, response_format, ttl, query_fee, opts]) do
    GenServer.start(
      __MODULE__,
      [%Client{} = client, query_format, response_format, ttl, query_fee, opts],
      name: __MODULE__
    )
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_queries() do
    GenServer.call(__MODULE__, :get_queries)
  end

  def new_query(client, query, query_ttl, response_ttl_value) do
    GenServer.call(__MODULE__, {:query, client, query, query_ttl, response_ttl_value})
  end

  def init([
        %Client{keypair: %{public: <<"ak_", rest::binary>>}} = client,
        query_format,
        response_format,
        ttl,
        query_fee
      ]) do
    possible_oracle_id = "ok_" <> rest

    with {:ok, _} <- Core.Oracle.get_oracle(client, possible_oracle_id) do
      schedule_work()

      {:ok,
       %{
         client: client,
         oracle_id: possible_oracle_id,
         query_format: query_format,
         response_format: response_format
       }}
    else
      {:error, _} ->
        {:ok, %{oracle_id: oracle_id}} =
          Core.Oracle.register(client, query_format, response_format, ttl, query_fee)

        schedule_work()

        {:ok,
         %{
           client: client,
           oracle_id: oracle_id,
           query_format: query_format,
           response_format: response_format
         }}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_queries, _from, %{client: client, oracle_id: oracle_id} = state) do
    {:ok, queries} = Core.Oracle.get_queries(client, oracle_id)
    {:reply, queries, state}
  end

  def handle_call(
        {:query, client, query, query_ttl, response_ttl_value},
        _from,
        %{oracle_id: oracle_id} = state
      ) do
    Core.Oracle.query(client, oracle_id, query, query_ttl, response_ttl_value)

    {:reply, :ok, state}
  end

  def handle_call({:respond, response_ttl}, _from, state) do
    respond_(state, response_ttl)
    {:reply, Core.Oracle.get_queries(state.client, state.oracle_id), state}
  end

  def handle_info(:work, state) do
    oracle_configuration = Application.get_env(:smart_oracle, :oracle)
    response_ttl = Keyword.get(oracle_configuration, :response_ttl, 1000)
    respond_(state, response_ttl)
    schedule_work()
    {:noreply, state}
  end

  defp respond_(state, response_ttl) do
    {:ok, queries} = Core.Oracle.get_queries(state.client, state.oracle_id)
    unresponded_queries = Enum.filter(queries, fn q -> q.response == "" end)
    api_call_client = Tesla.client([{Tesla.Middleware.BaseUrl, "https://api.binance.com/"}])

    Enum.each(unresponded_queries, fn q ->
      {:ok, t} = Tesla.get(api_call_client, "/api/v3/ticker/price", query: [symbol: q.query])

      {:ok, data} = Poison.decode(t.body)
      response_data = %{data["symbol"] => data["price"]}

      Core.Oracle.respond(state.client, state.oracle_id, q.id, response_data, response_ttl)
    end)
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 5000)
  end
end
