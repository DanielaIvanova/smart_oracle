# Smart Oracle
## Description  
**Smart Oracle** is an Elixir console application, made to automate the oracle job. 
User can load any account or even existing oracle in it.

If the given account **is not** an oracle yet, we register it.

If the given account **is already** an oracle we proceed to next step.

The next step is that our oracle will be making cycling requests to **AEternity blockchain node** and will list all queries sent to it, process them(for example we decided to connect it to Binance API, in order to get the trading course) and if the query is in right format(Like "BTCLTC"), the oracle will try to get the information from the data provider and if it succeeds, will respond to the query.

This approach allows us to implement any backend logic as the handling the data which is comming from outside of the blockchain and data providers can be almost everything.
## Usage

1. First of all you have set `config.exs` file, by providing your information. This is an example of `config.exs`: 

``` elixir
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
```
**NOTE:** This config will work only if you have your Aeternity node run at `http://localhost:3013/v2`


2. Clone the project and get the dependencies:
```
git clone https://github.com/DanielaIvanova/smart_oracle
cd smart_oracle
mix deps.get
```
3. Now you have to start the elixir app:
```
iex -S mix 
```
4. As we started our application, the app will try to connect to a given node, and if the connection is established, the given account will be registered as an oracle and will cycle requests to Aeternity blockchain.
5. **(OPTIONAL)** You can make a query to your own oracle, in order to test the oracle: 
``` elixir
state = SmartOracle.get_state # Gets the state, needed to get a client
SmartOracle.new_query(state.client, "LINKETH", %{type: :relative, value: 5000}, 1000) #Makes a query regarding LINK to ETH information
SmartOracle.new_query(state.client, "LINKBTC", %{type: :relative, value: 5000}, 1000) # Makes a query regarding LINK to BTC information
Core.Oracle.get_queries(state.client, state.oracle_id) # Lists all queries and you should see that they should have response from oracle(you might have to wait 5 seconds and execute the command again if there are no responses from the oracle)
```