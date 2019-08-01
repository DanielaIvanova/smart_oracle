defmodule SmartOracle.Supervisor do
  alias Core.Client
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    client_configuration = Application.get_env(:smart_oracle, :client)
    oracle_configuration = Application.get_env(:smart_oracle, :oracle)


    client =
      Client.new(
        %{
          public: Keyword.get(client_configuration, :pub_key),
          secret: Keyword.get(client_configuration, :secret_key)
        },
        Keyword.get(client_configuration, :network_id),
        Keyword.get(client_configuration, :url),
        Keyword.get(client_configuration, :internal_url),
        Keyword.get(client_configuration, :gas_price)
      )

    query_format = Keyword.get(oracle_configuration, :query_format)
    response_format = Keyword.get(oracle_configuration, :response_format)
    ttl = Keyword.get(oracle_configuration, :ttl)
    query_fee = Keyword.get(oracle_configuration, :query_fee)
    auth = Keyword.get(oracle_configuration, :auth, [])

    children = [
      {SmartOracle, [client, query_format, response_format, ttl, query_fee, auth]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
