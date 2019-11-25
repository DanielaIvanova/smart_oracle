defmodule SmartOracle do
  @moduledoc """
  Documentation for SmartOracle.
  """

  alias AeppSDK.{Oracle, Client}
  alias AeternityNode.Model.Account
  use GenServer
  require Logger

  @unresponded_queries_default_value ""
  @data_provider_base_url "https://api.binance.com/"
  @requested_info_path "/api/v3/ticker/price"
  @request_query "symbol"
  @prefix_byte_size 3
  @oracle_prefix "ok_"
  @default_timeout 5000
  @default_error_response %{"error" => "The query is invalid"}

  def start_link([%Client{}, _query_format, _response_format, _ttl, _query_fee, _opts] = args) do
    GenServer.start(
      __MODULE__,
      args,
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
    GenServer.cast(__MODULE__, {:query, client, query, query_ttl, response_ttl_value})
  end

  def init(
        [
          %Client{connection: connection, keypair: %{public: pubkey}} = client,
          _query_format,
          _response_format,
          _ttl,
          _query_fee,
          _opts
        ] = init_args
      ) do
    with {:ok, %Account{kind: "basic"}} <-
           AeternityNode.Api.Account.get_account_by_pubkey(connection, pubkey),
         {:ok, oracle_id} <- try_register_oracle(init_args),
         {:ok, %{id: ^oracle_id}} <- Oracle.get_oracle(client, oracle_id) do
      register_and_return_state(init_args)
    else
      {:ok, %Account{kind: "generalized"}} ->
        register_and_return_state(init_args)

      {:error, :econnrefused} ->
        info(
          "Couldn't connect to a node located at: #{
            inspect(Application.get_env(:smart_oracle, :client)[:url])
          }, please, check your node address, retrying in #{inspect(@default_timeout)} ms",
          @default_timeout
        )

        Process.sleep(@default_timeout)
        init(init_args)

      {:error, "Account not found"} ->
        prolonged_timeout = @default_timeout * 2

        info(
          "Account #{inspect(pubkey)} does not exist, retrying in #{prolonged_timeout}",
          prolonged_timeout
        )

        init(init_args)

      {:error, %_error_struct{reason: _reason}} ->
        register_and_return_state(init_args)
    end
  end

  def handle_cast(
        {:query, client, query, query_ttl, response_ttl_value},
        %{oracle_id: oracle_id} = state
      ) do
    Oracle.query(client, oracle_id, query, query_ttl, response_ttl_value)

    {:noreply, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_queries, _from, %{client: client, oracle_id: oracle_id} = state) do
    {:ok, queries} = Oracle.get_queries(client, oracle_id)
    {:reply, queries, state}
  end

  def handle_call({:respond, response_ttl}, _from, state) do
    respond_(state, response_ttl)
    {:reply, Oracle.get_queries(state.client, state.oracle_id), state}
  end

  def handle_info(:work, state) do
    oracle_configuration = Application.get_env(:smart_oracle, :oracle)
    response_ttl = Keyword.get(oracle_configuration, :response_ttl, 1000)
    respond_(state, response_ttl)
    {:noreply, state}
  end

  defp respond_(state, response_ttl) do
    case Oracle.get_queries(state.client, state.oracle_id) do
      {:ok, queries} ->
        # Responded queries could be reused later on
        %{unresponded_queries: unresponded_queries, responded_queries: _responded_queries} =
          Enum.reduce(queries, %{responded_queries: [], unresponded_queries: []}, fn query, acc ->
            case query.response do
              @unresponded_queries_default_value ->
                %{acc | unresponded_queries: [query | acc.unresponded_queries]}

              _other_values ->
                %{acc | responded_queries: [query | acc.responded_queries]}
            end
          end)

        api_call_client = Tesla.client([{Tesla.Middleware.BaseUrl, @data_provider_base_url}])

        Enum.each(unresponded_queries, fn q ->
          {:ok, %_struct{body: body}} =
            Tesla.get(api_call_client, @requested_info_path,
              query: [{String.to_atom(@request_query), q.query}]
            )

          {:ok, decoded_body} = Poison.decode(body)

          case decoded_body do
            %{"price" => _price, @request_query => _symbol} = response ->
              Oracle.respond(state.client, state.oracle_id, q.id, response, response_ttl)

            _ ->
              Oracle.respond(
                state.client,
                state.oracle_id,
                q.id,
                @default_error_response,
                response_ttl
              )
          end
        end)

      {:error, error} ->
        info(
          "Failed to get oracle queries: #{inspect(error)}, retrying in #{
            inspect(@default_timeout)
          } ms",
          @default_timeout
        )

        try_register_oracle([
          state.client,
          state.query_format,
          state.response_format,
          state.ttl,
          state.query_fee,
          state.opts
        ])
    end

    schedule_work()
  end

  defp info(reason, timeout) do
    Logger.info(reason)
    Process.sleep(timeout)
  end

  defp register_and_return_state(
         [%Client{} = client, query_format, response_format, ttl, query_fee, opts] = init_args
       ) do
    {:ok, oracle_id} = try_register_oracle(init_args)

    schedule_work()

    {:ok,
     %{
       client: client,
       oracle_id: oracle_id,
       query_format: query_format,
       response_format: response_format,
       ttl: ttl,
       query_fee: query_fee,
       opts: opts
     }}
  end

  defp try_register_oracle(
         [
           %Client{keypair: %{public: <<_prefix::binary-size(@prefix_byte_size), key::binary()>>}} =
             client,
           query_format,
           response_format,
           ttl,
           query_fee,
           opts
         ] = args
       ) do
    case Oracle.get_oracle(client, <<@oracle_prefix::binary, key::binary>>) do
      {:ok, %{id: oracle_id}} ->
        {:ok, oracle_id}

      {:error, "Oracle not found"} ->
        {:ok, %{oracle_id: oracle_id}} =
          Oracle.register(client, query_format, response_format, ttl, query_fee, opts)

        {:ok, oracle_id}

      {:error, :econnrefused} ->
        info(
          "Couldn't check/register an oracle, no connection to a node, retrying in #{
            @default_timeout
          } ms",
          @default_timeout
        )

        try_register_oracle(args)
    end
  end

  defp schedule_work() do
    Process.send_after(self(), :work, @default_timeout)
  end
end
