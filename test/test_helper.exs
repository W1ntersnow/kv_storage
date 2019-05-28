defmodule KVstore.TestCase do
  defmacro __using__(_) do
    quote do
      use ExUnit.Case
      use Plug.Test
      alias KVstore.Router

      @ttl Application.get_env(:kvstore, :ttl)

      setup do
        File.rm("storage")
        Application.stop(:kvstore)
        Application.start(:kvstore)
      end

      def call_patch_method(key, value, ttl \\ @ttl) do
        exec_call_pipeline(:patch, key, value, ttl)
      end

      def call_post_method(key, value, ttl \\ @ttl) do
        exec_call_pipeline(:post, key, value, ttl)
      end

      def exec_call_pipeline(type, key, value, ttl) do
        conn(type, "/", %{"key"=> key, "value" => value, "ttl" => ttl}) |> exec_call
      end

      def call_get_method(key \\ "") do
        conn(:get, "/#{key}", "") |> exec_call
      end

      def call_delete_method(key \\ "") do
        conn(:delete, "/#{key}", "") |> exec_call
      end

      def exec_call(conn) do
        Router.call(conn, Router.init([]))
      end
    end
  end


end
ExUnit.start()
