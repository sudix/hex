defmodule Mix.Tasks.Hex.Organization do
  use Mix.Task

  @shortdoc "Manages Hex.pm organizations"

  @moduledoc """
  Manages the list of authorized Hex.pm organizations.

  Organizations is a feature of Hex.pm to host and manage private packages. See
  <https://hex.pm/docs/private> for more information.

  By default you will be authorized to all your applications when running
  `mix hex.user auth` and this is the recommended approach. This task is mainly
  provided for a CI and build systems where access to an organization is needed
  without authorizing a user.

  By authorizing a new organization a new key is created for fetching packages
  from the organizations repository and the repository key is stored on the
  local machine.

  To use a package from an organization add `organization: "my_organization"` to the
  dependency declaration in `mix.exs`:

      {:plug, "~> 1.0", organization: "my_organization"}

  ## Authorize an organization

  This command will generate an API key used to authenticate access to the organization.
  See the `hex.user` tasks to list and control all your active API keys.

      mix hex.organization auth ORGANIZATION  [--key KEY] [--key-name KEY_NAME]

  ## Deauthorize and remove an organization

      mix hex.organization deauth NAME

  ## Generate a repository authentication key

  This command is useful to pre-generate keys for use with `mix hex.organization auth ORGANIZATION --key KEY`
  on CI servers or similar systems. It returns the hash of the generated key that you can pass to
  `auth ORGANIZATION --key KEY`. This key allows read-only access to the repository

      mix hex.organization key ORGANIZATION [--key-name KEY_NAME]

  ## List all authorized organizations

  This command will only list organizations you have authorized with this task, it will not
  list organizations you have access to by having authorized with `mix hex.user auth`.

      mix hex.organization list

  ## Command line options

    * `--key KEY` - Hash of key used to authenticate HTTP requests to repository, if
      omitted will generate a new key with your account credentials. This flag
      is useful if you have a key pre-generated with `mix hex.organization key`
      and want to authenticate on a CI server or similar system

    * `--key-name KEY_NAME` - By default Hex will base the key name on your machine's
      hostname and the organization name, use this option to give your own name.
  """

  @switches [key: :string, key_name: :string]

  def run(args) do
    Hex.start()
    {opts, args} = Hex.OptionParser.parse!(args, switches: @switches)

    case args do
      ["auth", name] ->
        auth(name, opts)

      ["deauth", name] ->
        deauth(name)

      ["key", name] ->
        key(name, opts)

      ["list"] ->
        list()

      _ ->
        Mix.raise("""
        Invalid arguments, expected one of:

        mix hex.organization auth ORGANIZATION
        mix hex.organization deauth ORGANIZATION
        mix hex.organization list
        """)
    end
  end

  defp auth(name, opts) do
    key = opts[:key]
    if opts[:key], do: test_key(key, name)
    key = key || Mix.Tasks.Hex.generate_organization_key(name, opts[:key_name])

    Mix.Tasks.Hex.auth_organization("hexpm:#{name}", key)
  end

  defp deauth(name) do
    Hex.State.fetch!(:repos)
    |> Map.delete("hexpm:#{name}")
    |> Hex.Config.update_repos()
  end

  defp key(name, opts) do
    Hex.Shell.info(Mix.Tasks.Hex.generate_organization_key(name, opts[:key_name]))
  end

  defp list() do
    Enum.each(Hex.State.fetch!(:repos), fn {name, _repo} ->
      case String.split(name, ":", parts: 2) do
        ["hexpm", name] ->
          Hex.Shell.info(name)

        _ ->
          :ok
      end
    end)
  end

  defp test_key(key, name) do
    case Hex.API.Auth.get("repository", name, key: key) do
      {:ok, {code, _body, _}} when code in 200..299 ->
        :ok

      other ->
        Hex.Utils.print_error_result(other)
        Mix.raise("Failed to authenticate against organization repository with given key")
    end
  end
end
