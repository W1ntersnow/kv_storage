defmodule KVstore.Storage do
  use GenServer
  require Logger
  alias KVstore.TTLworker

  @dets_path Application.get_env(:kvstore, :dets_path)
  @autosave Application.get_env(:kvstore, :autosave)

  @impl true
  def init(dets) do
    {:ok, dets}
  end

  def start_link() do
    db =
      case :dets.open_file(@dets_path, [type: :set, auto_save: @autosave]) do
        {:ok, ref} -> ref
        {:error, reason} -> GenServer.stop(__MODULE__, reason)
      end
    GenServer.start_link(__MODULE__, db, name: __MODULE__)
  end

  @impl true
  def terminate(reason, dets) do
    Logger.info "Terminating: #{inspect(reason)}"
    :dets.sync(dets)
    :dets.close(dets)
    :error
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  def create(key, value, ttl) when is_number(ttl) do
    GenServer.cast(__MODULE__, {:create, key, value, ttl})
  end

  def update(key, value, ttl) do
    GenServer.cast(__MODULE__, {:update, key, value, ttl})
  end

  def get_ttl(key) do
    GenServer.call(__MODULE__, {:get_ttl, key})
  end

  def exec_ttl() do
    GenServer.cast(__MODULE__, {:exec_ttl})
  end

  @impl true
  def handle_call({:get_ttl, key}, _from, dets) do
    result = case :dets.lookup(dets, key) do
      [{_, _, ttl}] -> ttl
      _ -> nil
    end
    {:reply, result, dets}
  end

  @impl true
  def handle_call({:get, key}, _from, dets) do
    result = case :dets.lookup(dets, key) do
      [{_, value, ttl}] -> get_value(key, value, ttl)
      _ -> ""
    end
    {:reply, result, dets}
  end

  @impl true
  def handle_cast({:delete, key}, dets) do
    :dets.delete(dets, key)
    {:noreply, dets}
  end

  @impl true
  def handle_cast({:create, key, value, ttl}, dets) do
    kv = {key, value, :erlang.system_time(:millisecond) + ttl}
    :dets.insert_new(dets, kv)
    TTLworker.delete_key_after(key, ttl)
    {:noreply, dets}
  end

  @impl true
  def handle_cast({:update, key, value, ttl}, dets) do
    case :dets.lookup(dets, key) do
      [{_, _, old_ttl}] -> :dets.insert(dets, {key, value, get_ttl(ttl, old_ttl)})
      [] -> nil
    end
    {:noreply, dets}
  end

  @impl true
  def handle_cast({:exec_ttl}, dets) do
    :dets.traverse(dets, fn(item) -> TTLworker.check_ttl(item) end)
    {:noreply, dets}
  end

  def get_ttl(new, old) do
    result = :erlang.system_time(:millisecond) + new
    if not is_nil(new) do
      result
    else
      old
    end
  end

  def get_value(key, value, ttl) do
    if ttl <= :erlang.system_time(:millisecond) do
      delete(key)
      []
    else
      value
    end
  end
end
