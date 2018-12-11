defmodule Ptolemy.Server do
  @moduledoc """
  Ptolemy server implements a genserver responsible in keeping a remote vault server's configuration data and 
  authentication data. For efficientcy reason, the authentication data which contains all necessary tokens to 
  authenticate through vault and IAP (if specified) are cached inside the state of the GenServer. This data is
  purged after EXP 
  """
  use GenServer
  alias Ptolemy.Auth

  @default_exp 900 #Default expiration for tokens
  @validation_err "Config error! Missing: "
  @req_m [:vault_url, :auth_mode, :credentials]

  @doc """
  Client side api to start a genserver. 
  """
  def start(pid, server) do
    config = 
      Application.get_env(:ptolemy, Ptolemy)
      |> Keyword.get(server)

    with {:ok, missing} <- validate(config) when missing == [] do
      GenServer.start_link(__MODULE__, config, name: pid)
    else
      {:error, missing} -> raise @validation_err <> missing
    end
  end
  
  @doc """
  Fetches access tokens. The access tokens will be returned as list of the proper HTTP headers. These can
  be inserted inside Tesla's middleware Headers.
  """
  def fetch_credentials(pid) do
    with {state, tokens} <- GenServer.call(pid, :fetch_creds) do
      case {state, tokens} do
        {:ok, tokens} -> tokens
        {:error, _ } -> GenServer.call(pid, :auth)
      end
    end
  end

  @doc """
  Client side function, will retrieve a specific value from the current genserver.
  """
  def get_data(pid, key) do
    GenServer.call(pid, {:fetch_conf, key})
  end

  @doc """
  Client side dump function, will retrieve the state of the current genserver.
  """
  def dump(pid) do
    GenServer.call(pid, :dump)
  end

  @doc """
  Validates the configuration that is fed to the start server.
  """
  defp validate(config) do
    validate(@req_m, config, {_,[]})
  end

  defp valiate(req_list, conf, status) do
    [head|tail] = req_list
    
    with {:ok, _ } <- Map.fetch(conf, head) do
      { _, missing} = status
      validate(tail, conf, {:ok, missing})
    else
      _ ->
        { _, missing} = status
        new_missing = [head | missing]
        validate(tail, conf, {:error, new_missing})
    end 
  end

  defp validate([], conf, status) do
    status
  end

  @doc """
  Returns an initilized configuration for a remote vault server.
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Purges the current access_tokens map. 
  """
  @impl true
  def handle_info(:purge_tok, state) do
    { _, newstate} = Map.pop(state, :access_tokens)
    {:noreply, newstate}
  end

  @doc """
  Handles initialization of the authentication process. This will return 
  """
  @impl true
  def handle_call(:auth, _from, state) do
    creds = Map.fetch!(state, :credentials)
    url = Map.fetch!(state, :vault_url)
    auth_mode = Map.fetch!(state, :auth_mode)
    opts = Map.fetch!(state, :opts)

    tokens = Auth.authenticate!(creds, auth_mode, url, opts)
    exp = opts |> Keyword.get(:exp, @default_exp)
    access_tokens = %{
      access_tokens: tokens
    }
    
    # we purge the tokens after X seconds
    Process.send_after(self(), :purge_tok, exp * 1000)

    {:reply, {:ok, tokens}, Map.merge(state, access_tokens)}
  end

  @doc """
  Fetches the access tokens and vault tokens inorder to make a call. This will return a list of tuples containing
  the relevant http headers, needed to authenticate to a remote vault server based on this GenServer's config.
  """
  @impl true
  def handle_call(:fetch_creds, _from, state) do
    with {:ok, return} <- Map.fetch(state, :access_tokens) do
      {:reply, {:ok, return}, state}
    else
      _ -> {:reply, {:error, "Not found!"}, state}
    end
  end

  @doc """
  Fetches a specific key from the genServer's state
  """
  @impl true
  def handle_call({:fetch_conf, key}, _from, state) do
    with {:ok, return} <- Map.fetch(state, key) do
      {:reply, {:ok, return}, state}
    else
      _ -> {:reply, {:error, "Not found!"}, state}
    end
  end

  @doc """
  Dumps the current state of the genserver.
  """
  def handle_call(:dump, _from, state) do
    {:reply, {:ok, state}, state}
  end
end
  