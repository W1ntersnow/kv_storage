defmodule KVstore.TTLworker do
  use GenServer

  def init(_) do
    Process.send(__MODULE__, :exec_ttl, [])
    {:ok, {}}
  end

  def delete_key_after(key, ttl) do
    Process.send_after(__MODULE__, {:delete, key}, ttl)
  end

  def handle_info({:delete, key}, state) do
    ttl = KVstore.get_ttl(key)
    current_ts = :erlang.system_time(:millisecond)
    case ttl do
      ttl when is_nil(ttl) -> nil
      ttl when ttl <= current_ts -> KVstore.delete(key)
      ttl when ttl > current_ts -> delete_key_after(key, ttl - current_ts)
    end
    {:noreply, state}
  end

  def handle_info(:exec_ttl, state) do
    KVstore.exec_ttl()
    {:noreply, state}
  end

  def check_ttl(item) do
    {key, _, ttl} = item
    current_ts = :erlang.system_time(:millisecond)
    if ttl <= current_ts do
      KVstore.delete(key)
    else
      delete_key_after(key, ttl)
    end
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

end
