defmodule KVstore.Utils do
  @moduledoc false
  require Logger
  def get_ttl(conn) do
    ttl = Map.get(conn.params, "ttl", nil)
    unless is_nil(ttl) do
      case Integer.parse(to_string(ttl)) do
        {ttl, _} -> ttl
        :error -> nil
      end
    end
  end

  def get_params(conn) do
    key = Map.get(conn.params, "key")
    value = Map.get(conn.params, "value")
    ttl = get_ttl(conn)
    {key, value, ttl}
  end

end
