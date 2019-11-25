use Mix.Config

config :smart_oracle, :client,
  pub_key: "ak_6A2vcm1Sz6aqJezkLCssUXcyZTX7X8D5UwbuS2fRJr9KkYpRU",
  secret_key:
    "a7a695f999b1872acb13d5b63a830a8ee060ba688a478a08c6e65dfad8a01cd70bb4ed7927f97b51e1bcb5e1340d12335b2a2b12c8bc5221d63c4bcb39d41e61",
  network_id: "my_test",
  url: "http://localhost:3013/v2",
  internal_url: "http://localhost:3013/v2",
  gas_price: 1_000_000_000,
  auth: []

config :smart_oracle, :oracle,
  query_format: "string",
  response_format: "map(string, string)",
  ttl: %{type: :relative, value: 10_000},
  query_fee: 10_000,
  response_ttl: 1000
