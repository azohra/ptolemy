# Simple

## Requirements

Please make sure you have docker available on your machine. We will be using a local vault server in our simple demo app. To simplify the process, we provided a docker-compose file to help you spin up the vault server. Also ensure neither port8200 nor port 8210 is being used by other applications.

Other requirements:
 - JQ (Commandline JSON Parser)
 - Elixir
 - Bash

## Using Simple

Make sure you are in the `/simple` directory. And getting started with our Simple demo is as easy as 1, 2, 3.

1. Run command
  ```
  docker-compose up
  ```
  This should start up a vault server. You may visit the server at `http://localhost:8200/ui/` and use token `Dzje67e6pyj3Wh1DqBBMAYYM` to log in.

2. Open up another terminal window and run command
  ```
  . vault_init.sh
  ``` 
  Our vault init script helps you configure the Vault server and system environment as needed, such as content and ACL policies.

3. Once step 2 is done, run the following command in the same terminal window
  ```
  mix deps.get && iex -S mix app.start
  ```

Now, you've started an interaction session with our Simple demo app. It automatically loaded three values, `kv_string`,`kv_integer` and `pki_cert`, from Vault into the application environment.
```
Application.get_env(:simple, :kv_string)
```
```
Application.get_env(:simple, :kv_integer)
```
```
Application.get_env(:simple, :pki_cert)
```

Since KV engine does not have TTL or lease_duration. We don't refresh the KV secrets. However, if the lease is configured, it is possible to refresh KV values as well. 

PKI secret is an example of dynamic secret loading. We set the TTL for it to **15s**, so if you run `Application.get_env(:simple, :pki_cert)` several times with at least 15 seconds in between. It would return a fresh updated certificate every 15s. Pay attention to the serial number to notice the difference, between results.

You can also play with the Vault interface we developed, you can start with

1. Starting a ptolemy server
  ```
  {:ok, server} = Ptolemy.start(:example_server, :simple_server)
  ```
2. Try to read the a secret from Vault's KV engine
  ```
  Ptolemy.read(server, :simple_kv_engine, [:simple_secret])
  ```
3. Update a secret in Vault
  ```
  Ptolemy.update(server, :simple_kv_engine, [:simple_secret, %{foo: "new value here", bar: "not a integer anymore"}])
  ```
  Note: The updated secret won't be loaded into Application environement due to lack of ttl, however, we might consider adding a method for user to call to refresh one secret manually. Currently, user would either have to write their own helper functions to reload secrets using Ptolemy's vault bindings or just restart the app.


Above is a simple demo of what Ptolemy, a dynamic application environment manager, is capable of. And it can add value to your applications by making your application more flexible without compromising security. Ptolemy is more than a Vault binding, there's a lot for you to discover!

## Contributor(s)

Written in 2019 as a demo project for Ptolemy by Saidi Tang <a href="https://www.linkedin.com/in/saidi-t/" target="_blank"><img src="https://static.licdn.com/scds/common/u/img/webpromo/btn_viewmy_160x25.png" width="160" height="25" border="0" alt="View my profile on LinkedIn"></a> 

If you are experiencing any problems with Ptolemy or this example project, please feel free to submit an issue!

Please contact Brandon or me if you have any feature request for Ptolemy. Or, simply open a PR and let us know how you have improved Ptolemy. Contributions are always welcomed :D
