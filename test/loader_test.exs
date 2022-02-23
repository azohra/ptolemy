defmodule Ptolemy.LoaderTest do
  use ExUnit.Case
  import Mox

  alias Ptolemy.{Loader, LoaderTest}

  defmodule EchoProvider do
    use Ptolemy.Provider
    def init(_self), do: :ok

    def load(_self, arg) do
      arg
    end
  end

  defmodule NeedyProvider do
    use Ptolemy.Provider

    def init(_) do
      # :needy_test = Application.get_env(:needy_test, :needy_test)

      case Application.get_env(:needy_test, :needy_test) do
        :needy_test -> :ok
        _ -> throw("My needs are not met!")
      end
    end

    def load(_, arg) do
      arg
    end
  end

  describe "Ptolemy.Loader" do
    setup :set_mox_global
    setup :verify_on_exit!

    test "loading a provider", %{test: test_name} do
      :ok = Loader.load({test_name, :load_this}, {LoaderTest.EchoProvider, "LOAD_ME"})
      assert Application.get_env(test_name, :load_this) == "LOAD_ME"
    end

    test "loader sets application value correctly", %{test: test_name} do
      expect(CacheMock, :clear_cache, fn -> true end)

      {:ok, _loader} =
        Loader.start_link(
          env: [
            {{test_name, :testval}, {LoaderTest.EchoProvider, "THIS_WORKED"}}
          ]
        )

      assert Application.get_env(test_name, :testval) == "THIS_WORKED"
    end

    test "recieving an expired message will re-pull value", %{test: test_name} do
      expect(CacheMock, :clear_cache, 2, fn -> true end)

      {:ok, loader} =
        Loader.start_link(
          env: [
            {{test_name, :testval}, {LoaderTest.EchoProvider, "loaded_value"}}
          ]
        )

      Application.put_env(test_name, :testval, "not_set")

      send(loader, {:expired, {LoaderTest.EchoProvider, "loaded_value"}})

      :sys.get_state(loader)

      assert Application.get_env(test_name, :testval) == "loaded_value"
    end

    test "initializing providers is lazy" do
      expect(CacheMock, :clear_cache, fn -> true end)

      Application.put_env(:needy_test, :needy_test, nil)

      {:ok, _loader} =
        Ptolemy.Loader.start_link(
          env: [
            {{:needy_test, :needy_test}, {LoaderTest.EchoProvider, :needy_test}},
            {{:needy_test, :needy_test}, {LoaderTest.NeedyProvider, :needy_test}}
          ]
        )

      assert Application.get_env(:needy_test, :needy_test) == :needy_test
    end

    test "initializing providers should update loader configuration" do
      expect(CacheMock, :clear_cache, fn -> true end)

      Application.put_env(
        :ptolemy,
        :loader,
        env: [
          {{:needy_test, :needy_test}, {LoaderTest.EchoProvider, :needy_test}},
          {{:needy_test, :needy_test}, {LoaderTest.NeedyProvider, :needy_test}}
        ]
      )

      {:ok, loader} = Ptolemy.Loader.start_link()

      assert Loader.config(loader) |> Keyword.get(:started) |> Enum.sort() == [
               Ptolemy.LoaderTest.EchoProvider,
               Ptolemy.LoaderTest.NeedyProvider
             ]
    end

    test "can set single nested application env variables", %{test: test_name} do
      expect(CacheMock, :clear_cache, fn -> true end)

      Application.put_env(test_name, :nest_top, [])

      {:ok, _loader} =
        Loader.start_link(
          env: [
            {{test_name, [:nest_top, :nest_level_one]},
             {LoaderTest.EchoProvider, "working_value"}}
          ]
        )

      assert Application.get_env(test_name, :nest_top) |> Keyword.get(:nest_level_one) ==
               "working_value"
    end

    test "can set deeply nested values in maps and keyword lists", %{test: test_name} do
      expect(CacheMock, :clear_cache, fn -> true end)

      Application.put_env(test_name, :nest_top,
        nest_level_one: %{nest_level_two: [nest_level_three: [nest_level_four: "empty_rn"]]}
      )

      {:ok, _loader} =
        Loader.start_link(
          env: [
            {{test_name,
              [:nest_top, :nest_level_one, :nest_level_two, :nest_level_three, :nest_level_four]},
             {LoaderTest.EchoProvider, "its_dark_down_here"}}
          ]
        )

      assert Application.get_env(test_name, :nest_top)
             |> Keyword.get(:nest_level_one)
             |> Map.get(:nest_level_two)
             |> Keyword.get(:nest_level_three)
             |> Keyword.get(:nest_level_four) == "its_dark_down_here"
    end

    test "sets undefined top level configs still expressed in a nest list", %{test: test_name} do
      expect(CacheMock, :clear_cache, fn -> true end)

      {:ok, _loader} =
        Loader.start_link(
          env: [
            {{test_name, [:nest_top]}, {LoaderTest.EchoProvider, "working_value"}}
          ]
        )

      assert Application.get_env(test_name, :nest_top) == "working_value"
    end
  end
end
