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

  def query(client, query, query_ttl, response_ttl_value) do
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
      {:ok,
       %{
         client: client,
         oracle_id: possible_oracle_id,
         query_format: query_format,
         response_format: response_format,
         query_ids: []
       }}
    else
      {:error, _} ->
        {:ok, %{oracle_id: oracle_id}} =
          Core.Oracle.register(client, query_format, response_format, ttl, query_fee)

        {:ok,
         %{
           client: client,
           oracle_id: oracle_id,
           query_format: query_format,
           response_format: response_format,
           query_ids: []
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
        %{oracle_id: oracle_id, query_ids: query_ids} = state
      ) do
    {:ok, %{query_id: query_id}} =
      Core.Oracle.query(client, oracle_id, query, query_ttl, response_ttl_value)

    new_state = %{state | query_ids: [query_id | query_ids]}
    {:reply, new_state, new_state}
  end

  def respond(state, response_ttl) do
    {:ok, queries} = Core.Oracle.get_queries(state.client, state.oracle_id)
    unresponded_queries = Enum.filter(queries, fn q -> q.response != "" end)
    api_call_client = Tesla.client([{Tesla.Middleware.BaseUrl, "https://api.binance.com/"}])

    Enum.each(unresponded_queries, fn q ->
      {:ok, t} = Tesla.get(api_call_client, "/api/v3/ticker/price")
      Poison.decode(t.body)
    end)
  end
end
