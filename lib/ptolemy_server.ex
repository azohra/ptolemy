defmodule Ptolemy.Server do
  @moduledoc """
  `Ptolemy.Server` is responsible for the management of a remote backend's server's data.

  Data that `Ptolemy.Server` manages includes but not limited to:
    - Authentication Data to a remote vault server and its lifecycle
    - IAP authentication and its lifecyle
  """

  use GenServer
  alias Ptolemy.Auth
  require Logger

  # Default expiration for tokens (15 min in seconds)
  @validation_err "Config error! Missing: "
  @req [:vault_url, :auth]

  @doc """
  Start a genserver pointing to a remote server.

  When starting you may provide runtime configuration to Ptolemy by specifying a keyword list with the overiding values.
  """
  @spec start_link(atom(), map(), keyword()) :: GenServer.on_start()
  def start_link(pid, server, opts \\ []) do
    config =
      Application.get_env(:ptolemy, :vaults)
      |> Map.get(server)
      |> overide?(opts)

    with {:ok, []} <- validate(config) do
      GenServer.start_link(__MODULE__, config, name: pid)
    else
      {:error, missing} -> raise @validation_err <> "#{missing}"
    end
  end

  @doc """
  Fetches access tokens needed to authenticate against a remote vault server.

  Returns a list of tuple(s) containing the access tokens. If IAP is enabled its corresponding `bearer` token
  will also be returned as part of this list.
  """
  @spec fetch_credentials(atom()) :: nonempty_list(tuple()) | {:error, String.t()}
  def fetch_credentials(pid) do
    with {state, tokens} <- GenServer.call(pid, :fetch_creds) do
      case {state, tokens} do
        {:ok, tokens} ->
          tokens

        {:error, _} ->
          with {:ok, tok} <- GenServer.call(pid, :auth, 15000) do
            tok
          else
            {:error, _msg} = err -> err
          end
      end
    end
  end

  @doc """
  Set a key within a specified server's state.
  """
  @spec set_data(atom(), atom(), map()) :: :ok | {:error, String.t()}
  def set_data(pid, key, payload) do
    GenServer.call(pid, {:set, key, payload})
  end

  @doc """
  Get a specific key within a ptolemy state.
  """
  @spec get_data(atom(), atom()) :: {:ok, any()} | {:error, String.t()}
  def get_data(pid, key) do
    GenServer.call(pid, {:fetch, key})
  end

  @doc """
  Dumps entire state within a specified server.
  """
  @spec dump(atom()) :: {:ok, any()}
  def dump(pid) do
    GenServer.call(pid, :dump)
  end

  ##############################################################################################
  ######################################## Private land ########################################
  ##############################################################################################

  # Validates the configuration that is fed to the start server. Ptolemy requires a list of keys to
  # be presents in the configuration before it can attempt to make a connection with a remote vault
  # server.
  defp validate(config) do
    validate(@req, config, {:ok, []})
  end

  # Validate helper functions.
  defp validate([], _conf, status) do
    case status do
      {:ok, []} -> {:ok, []}
      {:error, missing} -> {:error, missing}
    end
  end

  defp validate(req_list, conf, {code, missing}) do
    [head | tail] = req_list

    status = Map.has_key?(conf, head)

    case {status, code, missing} do
      {true, :ok, []} -> validate(tail, conf, {:ok, []})
      {false, :ok, []} -> validate(tail, conf, {:error, [Atom.to_string(head)]})
      {true, :error, _} -> validate(tail, conf, {:error, missing})
      {false, :error, _} -> validate(tail, conf, {:error, [Atom.to_string(head) | missing]})
    end
  end

  # helper functions to overide conf
  defp overide?(map, opts) do
    if opts == [] do
      map
    else
      overide(map, Keyword.keys(opts), opts)
    end
  end

  defp overide(map, [head | tail], opts) do
    v = Keyword.get(opts, head)
    new_map = Map.put(map, head, v)
    overide(new_map, tail, opts)
  end

  defp overide(map, [], _opts), do: map

  defp parse_opts(opts) when is_list(opts) do
    case opts do
      [] ->
        []

      _ ->
        svc = Keyword.get(opts, :iap_svc_acc)

        case svc do
          :reuse -> opts
          _ -> opts |> Keyword.replace!(:iap_svc_acc, svc |> Jason.decode!())
        end
    end
  end

  defp parse_opts(opts) do
    opts
  end

  defp parse_creds(creds) do
    case creds do
      %{gcp_svc_acc: svc, vault_role: _role, exp: _exp} ->
        {:ok, Map.replace!(creds, :gcp_svc_acc, svc |> Jason.decode!())}

      %{secret_id: _id, role_id: _rid} = parsed ->
        {:ok, parsed}

      _ ->
        {:error, "Unsupported credentials format"}
    end
  end

  ##############################################################################################
  ################################## GenServer implementation ##################################
  ##############################################################################################

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:auth, _from, state) do
    url = Map.fetch!(state, :vault_url)
    auth = Map.fetch!(state, :auth)

    %{
      method: mode,
      credentials: creds,
      opts: options,
      auto_renew: auto_renew
    } = auth

    opts = options |> parse_opts

    with {:ok, parsed_creds} <- parse_creds(creds) do
      case Auth.authenticate(mode, url, parsed_creds, opts) do
        %{
          vault: %{token: token, renewable: renewable, lease_duration: ttl},
          iap: %{token: iap_tok}
        } = res ->
          access_token = [token, iap_tok]

          if renewable and auto_renew do
            Process.send_after(
              self(),
              {:auto_renew_vault, mode, url, parsed_creds, opts},
              (ttl - 5) * 1000
            )

            Process.send_after(self(), {:auto_renew_iap, opts}, (opts[:exp] - 5) * 1000)
          else
            Process.send_after(self(), {:purge, :vault}, ttl * 1000)
            Process.send_after(self(), {:purge, :iap}, opts[:exp] * 1000)
          end

          {:reply, {:ok, res}, Map.put(state, :tokens, access_token)}

        %{token: token, renewable: renewable, lease_duration: ttl} = res ->
          access_token = [token]

          if renewable and auto_renew do
            Process.send_after(
              self(),
              {:auto_renew_vault, mode, url, parsed_creds, opts},
              (ttl - 5) * 1000
            )
          else
            Process.send_after(self(), {:purge, :all}, ttl * 1000)
          end

          {:reply, {:ok, res}, Map.put(state, :tokens, access_token)}

        {:error, msg} ->
          {:reply, {:error, msg}, state}
      end
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  @impl true
  def handle_call(:fetch_creds, _from, state) do
    with {:ok, return} <- Map.fetch(state, :tokens) do
      {:reply, {:ok, return}, state}
    else
      _ -> {:reply, {:error, "Not found!"}, state}
    end
  end

  @impl true
  def handle_call({:fetch, key}, _from, state) do
    with {:ok, return} <- Map.fetch(state, key) do
      {:reply, {:ok, return}, state}
    else
      _ -> {:reply, {:error, "Not found!"}, state}
    end
  end

  @impl true
  def handle_call({:set, key, payload}, _from, state) do
    with true <- Map.has_key?(state, key) do
      nstate = Map.replace!(state, key, payload)
      {:reply, :ok, nstate}
    else
      _ -> {:reply, {:error, "Key Not found!"}, state}
    end
  end

  @impl true
  def handle_call(:dump, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_info({:purge, op}, state) do
    toks = Map.get(state, :tokens)

    case {op, length(toks)} do
      {:all, _} ->
        {_, newstate} = Map.pop(state, :tokens)
        {:noreply, newstate}

      {:vault, 1} ->
        {_, newstate} = Map.pop(state, :tokens)
        {:noreply, newstate}

      {:vault, 2} ->
        [{"X-Vault-Token", _bearer}, token] = toks
        {:noreply, Map.put(state, :tokens, [token])}

      {:iap, 2} ->
        [token, {"Authorization", _bearer}] = toks
        {:noreply, Map.put(state, :tokens, [token])}
    end
  end

  @impl true
  def handle_info({:auto_renew_iap, opts}, state) do
    [vault_tok, {"Authorization", _bearer}] = Map.get(state, :tokens)

    creds =
      case opts[:iap_svc_acc] do
        :reuse ->
          state
          |> Map.get(:auth)
          |> Map.get(:credentials)
          |> Map.get(:gcp_svc_acc)
          |> Jason.decode!()

        _ ->
          opts[:iap_svc_acc]
      end

    new_iap = Ptolemy.Auth.Google.authenticate(:iap, creds, opts[:client_id], opts[:exp])
    Process.send_after(self(), {:auto_renew_iap, opts}, opts[:exp] - 5)
    {:noreply, Map.put(state, :tokens, [vault_tok, new_iap])}
  end

  @impl true
  def handle_info({:auto_renew_vault, mode, url, parsed_creds, opts}, state) do
    toks = Map.get(state, :tokens)

    case length(toks) do
      1 ->
        %{
          token: token,
          renewable: renewable,
          lease_duration: ttl
        } = Auth.authenticate(mode, url, parsed_creds, opts)

        if renewable do
          Process.send_after(
            self(),
            {:auto_renew_vault, mode, url, parsed_creds, opts},
            (ttl - 5) * 1000
          )
        else
          Process.send_after(self(), {:purge, :vault}, ttl * 1000)
        end

        {:noreply, Map.put(state, :tokens, [token])}

      2 ->
        [{"X-Vault-Token", _bearer}, bearer] = toks

        %{
          vault: %{token: token, renewable: renewable, lease_duration: ttl},
          iap: _map
        } = Auth.authenticate(mode, url, parsed_creds, opts)

        if renewable do
          Process.send_after(
            self(),
            {:auto_renew_vault, mode, url, parsed_creds, opts},
            (ttl - 5) * 1000
          )
        else
          Process.send_after(self(), {:purge, :vault}, ttl * 1000)
        end

        {:noreply, Map.put(state, :tokens, [token, bearer])}
    end
  end

  @impl true
  def format_status(:terminate, _pdict_and_state) do
    Logger.error("Ptolemy server abrubtly terminated")
  end
end
