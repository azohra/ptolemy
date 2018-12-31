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
  @req [:vault_url, :auth_mode, :credentials]

  @doc """
  Client side api to start a genserver. 
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
  Fetches access tokens. The access tokens will be returned as list of the proper HTTP headers. These can
  be inserted inside Tesla's middleware Headers.
  """
  def fetch_credentials(pid) do
    with {state, tokens} <- GenServer.call(pid, :fetch_creds)
    #CHECK VALIDITY OF THE TOKEN TO SEE IF IT WILL EXPIRE SOON    
    do
      case {state, tokens} do
        {:ok, tokens} -> tokens
        {:error, _ } -> 
          {:ok, tok} = GenServer.call(pid, :auth)
          tok
      end
    end
  end

  def set_data(pid, key, payload) do
    GenServer.call(pid, {:set, key, payload})
  end

  @doc """
  Client side function, will set a new value to a specific key in the state.
  """
  def get_data(pid, key) do
    GenServer.call(pid, {:fetch, key})
  end

  @doc """
  Client side dump function, will retrieve the state of the current genserver.
  """
  def dump(pid) do
    GenServer.call(pid, :dump)
  end

  @doc """
  Validates the configuration that is fed to the start server. Ptolemy requires a list of keys to
  be presents in the configuration before it can attempt to make a connection with a remote vault
  server.
  """
  def validate(config) do
    validate(@req, config, {:ok,[]})
  end

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
  def handle_call({:fetch, key}, _from, state) do
    with {:ok, return} <- Map.fetch(state, key) do
      {:reply, {:ok, return}, state}
    else
      _ -> {:reply, {:error, "Not found!"}, state}
    end
  end

  @doc """
  Sets a new value for a specific key in the state
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
end
  