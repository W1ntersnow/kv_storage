defmodule KVstore.Test do
  use KVstore.TestCase

  @ttl Application.get_env(:kvstore, :ttl)
  @lag 5

  describe "service api tests" do
    test "create row and ttl work" do
      response = call_post_method("create_and_ttl_work_key", "create_and_ttl_work_value")
      assert response.status == 201

      :timer.sleep(@lag)

      response = call_get_method("create_and_ttl_work_key")
      assert response.resp_body == "create_and_ttl_work_value"

      :timer.sleep(@ttl + @lag)

      response = call_get_method("create_and_ttl_work_key")
      assert response.resp_body == ""
    end

    test "upd row with no change ttl" do
      response = call_post_method("no_change_ttl_key", "no_change_ttl_value")
      assert response.status == 201

      :timer.sleep(@lag)

      response = call_patch_method("no_change_ttl_key", "updated_no_change_ttl_value")
      assert response.status == 201

      :timer.sleep(@lag)

      response = call_get_method("no_change_ttl_key")
      assert response.resp_body == "updated_no_change_ttl_value"

      :timer.sleep(@ttl + 5)

      response = call_get_method("no_change_ttl_key")
      assert response.resp_body == ""
    end

    test "upd row with change ttl" do
      response = call_post_method("change_ttl_key", "change_ttl_value")
      assert response.status == 201

      :timer.sleep(@lag)

      response = call_patch_method("change_ttl_key", "change_ttl_value", @ttl * 2)
      assert response.status == 201

      :timer.sleep(@ttl + 5)

      response = call_get_method("change_ttl_key")
      assert response.resp_body == "change_ttl_value"

      :timer.sleep(@ttl + 5)

      response = call_get_method("change_ttl_key")
      assert response.resp_body == ""
    end

    test "del existing row" do
      response = call_post_method("del_existing_row_key", "del_existing_row_value")
      assert response.status == 201

      :timer.sleep(@lag)

      response = call_get_method("del_existing_row_key")
      assert response.resp_body == "del_existing_row_value"

      :timer.sleep(@lag)

      response = call_delete_method("del_existing_row_key")
      assert response.status == 200

      :timer.sleep(@lag)

      response = call_get_method("del_existing_row_key")
      assert response.status == 200
      assert response.resp_body == ""
    end

    test "nonexistent row" do
      response = call_get_method("nonexistent_key")
      assert response.status == 200
      assert response.resp_body == ""
    end

    test "mass create and ttl (100)" do
      recursive_create(100)

      :timer.sleep(@lag)

      recursive_get(100)
    end

    test "mass create and ttl (1000)" do
      recursive_create(1000)

      :timer.sleep(@lag)

      recursive_get(1000)
    end

    test "mass create and ttl (10000)" do
      recursive_create(10000)

      :timer.sleep(@lag)

      recursive_get(10000)
    end

    def recursive_create(n) when n == 1 do
      exec_call_pipeline(:post, to_string(n), to_string(n), @ttl)
    end

    def recursive_create(n) do
      exec_call_pipeline(:post, to_string(n), to_string(n), @ttl)
      recursive_create(n-1)
    end

    def get_and_assert(n) do
      response = n |> to_string |> call_get_method
      assert response.resp_body == to_string(n)
    end

    def recursive_get(n) when n <= 1 do
      get_and_assert(n)
    end

    def recursive_get(n) do
      get_and_assert(n)
      recursive_create(n-1)
    end
  end
end
