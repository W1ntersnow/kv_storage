defmodule KVstore.Storage do
  use GenServer
  require Logger

  @dets_path Application.get_env(:kvstore, :dets_path)
  @autosave Application.get_env(:kvstore, :autosave)
  @expire_sleep Application.get_env(:kvstore, :expire_sleep)

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
    Task.start_link(fn -> expiration_check() end)
    GenServer.start_link(__MODULE__, db, name: __MODULE__)
  end

  @impl true
  def terminate(reason, dets) do
    Logger.info "Terminating: #{inspect(reason)}"
    :dets.sync(dets)
    :dets.close(dets)
    :error
  end

  defp expiration_check() do
    GenServer.cast(__MODULE__, :expire)
    Process.sleep(@expire_sleep)
    expiration_check()
  end

  @impl true
  def handle_cast(:expire, dets) do
    now = System.system_time(:millisecond)
    match_spec = [{{:_, :_, :"$1"}, [{:<, :"$1", {:const, now}}], [true]}]
    qty = :dets.select_delete(dets, match_spec)
    if qty > 0 do
      Logger.info "#{qty} rows expired"
    end
    {:noreply, dets}
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

  @impl true
  def handle_call({:get, key}, _from, dets) do
    result = case :dets.lookup(dets, key) do
      [{_, value, ttl}] -> get_value(key, value, ttl)
      _ -> ""
    end
    {:reply, result, dets}
  end

  def handle_cast({:delete, key}, dets) do
    :dets.delete(dets, key)
    {:noreply, dets}
  end

  def handle_cast({:create, key, value, ttl}, dets) do
    kv = {key, value, :erlang.system_time(:millisecond) + ttl}
    :dets.insert_new(dets, kv)
    {:noreply, dets}
  end

  def handle_cast({:update, key, value, ttl}, dets) do
    case :dets.lookup(dets, key) do
      [{_, _, old_ttl}] -> :dets.insert(dets, {key, value, get_ttl(ttl, old_ttl)})
      [] -> nil
    end
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
      KVstore.delete(key)
      []
    else
      value
    end
  end
end
