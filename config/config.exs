# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :tesla, adapter: Tesla.Adapter.Hackney
<<<<<<< HEAD
=======

import_config "#{Mix.env()}.exs"
>>>>>>> origin/refactor/kv-binding
