# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :tesla, adapter: Tesla.Adapter.Hackney

import_config "#{Mix.env()}.exs"
