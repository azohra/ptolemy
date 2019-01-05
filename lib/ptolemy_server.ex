defmodule Ptolemy.Server do
  @moduledoc """
  Ptolemy server is responsible in keeping a remote vault server's configuration data and  authentication data. 
  """

  use GenServer
  alias Ptolemy.Auth
  require Logger

  @default_exp 900 # Default expiration for tokens (15 min in seconds)
  @validation_err "Config error! Missing: "
  @req [:vault_url, :auth_mode, :credentials]

  @doc """
  Starts a ptolemy server that will hold state.
  """
  def start(pid, server) do
    config = 
      Application.get_env(:ptolemy, Ptolemy)
      |> Keyword.get(server)

    with {:ok, []} <- validate(config) do
      GenServer.start_link(__MODULE__, config, name: pid)
    else
      {:error, missing} -> raise @validation_err <> "#{missing}"
    end
  end
  
  @doc """
  Fetches access tokens needed to authenticate request to vault and IAP (if enabled). Returns a list of tuple(s)
  containing the tokens.
  """
  def fetch_credentials(pid) do
    with {state, tokens} <- GenServer.call(pid, :fetch_creds)
    do
      case {state, tokens} do
        {:ok, tokens} -> tokens
        {:error, _ } -> 
          {:ok, tok} = GenServer.call(pid, :auth)
          tok
      end
    end
  end

  @doc """
  Sets data within a ptolemy state.
  """
  def set_data(pid, key, payload) do
    GenServer.call(pid, {:set, key, payload})
  end

  @doc """
  Get a specific key within a ptolemy state.
  """
  def get_data(pid, key) do
    GenServer.call(pid, {:fetch, key})
  end

  @doc """
  Dumps entire state within the ptolemy state.
  """
  def dump(pid) do
    GenServer.call(pid, :dump)
  end

  @doc """
  Validates the configuration that is fed to the start server. Ptolemy requires a list of keys to
  be presents in the configuration before it can attempt to make a connection with a remote vault
  server.
  """
  defp validate(config) do
    validate(@req, config, {:ok,[]})
  end

  @doc """
  Validate helper functions.
  """
  defp validate([], _conf, status) do
    case status do 
      {:ok, []} -> {:ok, []}
      {:error, missing} -> {:error, missing}
    end
  end

  defp validate(req_list, conf, {code, missing}) do
    [head|tail] = req_list

    status = Map.has_key?(conf, head)
    
    case {status, code, missing} do
      {true, :ok, []} -> validate(tail, conf, {:ok, []})
      {false, :ok, []} ->  validate(tail, conf, {:error, [Atom.to_string(head)]})
      {true, :error, _ } ->  validate(tail, conf, {:error, missing})
      {false, :error, _ } ->  validate(tail, conf, {:error, missing ++ [Atom.to_string(head)]})
    end
  end

  @doc """
  Handles initilization of the ptolemy server.
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
  Handles initialization of the authentication process. This will return the necessary HTTP header tokens to the
  caller additionally these tokens will be automatically purged after `exp` seconds 
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
  Fetches all necessary tokens needed to send request to a remote vautl server.
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
  Fetches a specific key's value from the state
  """
  @impl true
  def handle_call({:fetch, key}, _from, state) do
    with {:ok, return} <- Map.fetch(state, key) do
      {:reply, {:ok, return}, state}
    else
      _ -> {:reply, {:error, "Not found!"}, state}
    end
  end

  @doc """
  Sets a new value for a specific key in the state.
  """
  @impl true
  def handle_call({:set, key, payload}, _from, state) do
    with {:ok, return} <- Map.fetch(state, key) do
      nstate = Map.replace!(state, key, payload)
      {:reply, :ok, nstate}
    else
      _ -> {:reply, {:error, "Key Not found!"}, state}
    end
  end

  @doc """
  Dumps the current state of the genserver.
  """
  def handle_call(:dump, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @doc """
  Formats the status of the current ptolemy state, this is done to prevent 
  """
  def format_status(:terminate, pdict_and_state) do
    Logger.error "Ptolemy server abrubtly terminated"
  end
end
  