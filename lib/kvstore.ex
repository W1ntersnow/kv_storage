defmodule KVstore do
  use Application
  use Supervisor
  require Logger

  @port Application.get_env(:kvstore, :port)
  @ttl Application.get_env(:kvstore, :ttl)

  defdelegate get(key), to: KVstore.Storage

  defdelegate delete(key), to: KVstore.Storage

  defdelegate update(key, value, ttl \\ nil), to: KVstore.Storage

  defdelegate create(key, value, ttl \\ @ttl), to: KVstore.Storage

  defdelegate get_ttl(key), to: KVstore.Storage

  defdelegate exec_ttl(), to: KVstore.Storage

  def create(key), do: create(key, key, @ttl)

  @impl true
  def init(_) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, KVstore.Router, [], port: @port),
      worker(KVstore.Storage, [], restart: :permanent),
      worker(KVstore.TTLworker, [], restart: :permanent)
    ]
    supervise(children, strategy: :one_for_one)
  end

  @impl true
  def start(_type, _args) do
    Logger.info "KVstore started"
    Supervisor.start_link(__MODULE__, [])
  end
end
