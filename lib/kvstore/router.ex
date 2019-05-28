defmodule KVstore.Router do
  use Plug.Router

  require Logger
  import KVstore.Utils

  plug(:match)
  plug(:dispatch)

  get "/:key", do: send_resp(conn, 200, KVstore.get(key))

  delete "/:key", do: delete_handler(conn, key)

  post "/", do: post_handler(conn)

  patch "/", do: patch_handler(conn)

  match(_, do: send_resp(conn, 404, "Not found"))

  defp delete_handler(conn, key) do
    KVstore.delete(key)
    send_resp(conn, 200, "Ok!")
  end

  defp post_handler(conn) do
    conn = fetch_query_params(conn)
    {key, value, ttl} = get_params(conn)
    KVstore.create(key, value, ttl)
    send_resp(conn, 201, "Ok!")
  end

  defp patch_handler(conn) do
    conn = fetch_query_params(conn)
    {key, value, ttl} = get_params(conn)
    KVstore.update(key, value, ttl)
    send_resp(conn, 201, "Ok!")
  end
end
