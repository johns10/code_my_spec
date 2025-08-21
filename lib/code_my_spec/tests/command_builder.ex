defmodule CodeMySpec.Tests.CommandBuilder do
  @moduledoc """
  Constructs mix test command strings with ExUnit JSON formatter and configurable options.
  """

  @type build_opts :: [
    include: [atom()],
    exclude: [atom()],
    seed: non_neg_integer(),
    max_failures: pos_integer(),
    only: [String.t()],
    stale: boolean(),
    failed: boolean(),
    trace: boolean()
  ]

  @spec build_command(build_opts()) :: String.t()
  def build_command(opts \\ []) do
    base = "mix test --formatter ExUnitJsonFormatter"
    
    opts
    |> Enum.reduce(base, &add_option/2)
  end

  @spec validate_opts(build_opts()) :: :ok | {:error, String.t()}
  def validate_opts(opts) do
    with :ok <- validate_include_exclude_conflict(opts),
         :ok <- validate_seed(opts[:seed]),
         :ok <- validate_max_failures(opts[:max_failures]),
         :ok <- validate_boolean_option(opts[:stale], :stale),
         :ok <- validate_boolean_option(opts[:failed], :failed),
         :ok <- validate_boolean_option(opts[:trace], :trace) do
      :ok
    end
  end

  defp add_option({:include, tags}, acc) when is_list(tags) do
    tags_str = tags |> Enum.map(&to_string/1) |> Enum.join(",")
    acc <> " --include #{tags_str}"
  end

  defp add_option({:exclude, tags}, acc) when is_list(tags) do
    tags_str = tags |> Enum.map(&to_string/1) |> Enum.join(",")
    acc <> " --exclude #{tags_str}"
  end

  defp add_option({:seed, seed}, acc) when is_integer(seed) and seed > 0 do
    acc <> " --seed #{seed}"
  end

  defp add_option({:max_failures, max}, acc) when is_integer(max) and max > 0 do
    acc <> " --max-failures #{max}"
  end

  defp add_option({:only, files}, acc) when is_list(files) do
    files
    |> Enum.reduce(acc, fn file, acc_inner ->
      acc_inner <> " --only #{file}"
    end)
  end

  defp add_option({:stale, true}, acc), do: acc <> " --stale"

  defp add_option({:failed, true}, acc), do: acc <> " --failed"

  defp add_option({:trace, true}, acc), do: acc <> " --trace"

  defp add_option(_, acc), do: acc

  defp validate_include_exclude_conflict(opts) do
    include_tags = opts[:include] || []
    exclude_tags = opts[:exclude] || []
    
    conflicts = include_tags -- (include_tags -- exclude_tags)
    
    case conflicts do
      [] -> :ok
      conflicts -> {:error, "Conflicting include/exclude tags: #{inspect(conflicts)}"}
    end
  end

  defp validate_seed(nil), do: :ok
  defp validate_seed(seed) when is_integer(seed) and seed > 0, do: :ok
  defp validate_seed(seed), do: {:error, "Invalid seed: #{inspect(seed)} (must be positive integer)"}

  defp validate_max_failures(nil), do: :ok
  defp validate_max_failures(max) when is_integer(max) and max > 0, do: :ok
  defp validate_max_failures(max), do: {:error, "Invalid max_failures: #{inspect(max)} (must be positive integer)"}

  defp validate_boolean_option(nil, _key), do: :ok
  defp validate_boolean_option(value, _key) when is_boolean(value), do: :ok
  defp validate_boolean_option(value, key), do: {:error, "Invalid #{key}: #{inspect(value)} (must be boolean)"}
end