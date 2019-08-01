defmodule SmartOracle.Application do
  @moduledoc """
  Main application supervisor
  """
  use Application

  def start(_type, _args) do
    children = [
      SmartOracle.Supervisor
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
