defmodule Ptolemy.ProviderTest do
  use ExUnit.Case

  defmodule TestProvider do
    use Ptolemy.Provider

    def init(_loader_pid), do: :ok

    def load(_loader_pid, _query), do: "none"
  end

  test "register_ttl will regester the ttl properly" do
    Ptolemy.ProviderTest.TestProvider.register_ttl(self(), "test_query", 1, :milliseconds)
    assert_receive({:expired, {Ptolemy.ProviderTest.TestProvider, "test_query"}}, 2)
  end

  describe "ttl conversions:" do
    test "convert millis to millis" do
      assert Ptolemy.Provider.to_millis(10, :milliseconds) == 10
    end

    test "convert seconds to millis" do
      assert Ptolemy.Provider.to_millis(7, :seconds) == 7000
    end

    test "convert minutes to millis" do
      assert Ptolemy.Provider.to_millis(3, :minutes) == 180_000
    end

    test "convert hours to millis" do
      assert Ptolemy.Provider.to_millis(5, :hours) == 1.8e+7
    end
  end
end
