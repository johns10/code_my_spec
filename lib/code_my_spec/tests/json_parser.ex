defmodule CodeMySpec.Tests.JsonParser do
  @moduledoc """
  Parses ExUnit JSON formatter output into structured TestRun data.
  Pure functional core that transforms raw JSON strings into validated embedded schemas.
  """

  alias CodeMySpec.Tests.{TestRun, TestResult, TestStats, TestError}

  @type json_event ::
          {:start, %{including: [String.t()], excluding: [String.t()]}}
          | {:pass, %{title: String.t(), full_title: String.t()}}
          | {:fail, %{title: String.t(), full_title: String.t(), err: map()}}
          | {:end, map()}

  @type parse_error ::
          {:invalid_json, %{line: String.t(), reason: term()}}
          | {:unknown_event, %{event: term()}}
          | {:malformed_event, %{event: term(), field: atom()}}

  @spec parse_json_output(String.t()) :: {:ok, TestRun.t()} | {:error, parse_error()}
  def parse_json_output(raw_output) do
    # Try to parse as ExUnitJsonFormatter output (single JSON object)
    case parse_exunit_json_formatter(raw_output) do
      {:ok, test_run} -> {:ok, test_run}
      {:error, _} ->
        # Fallback to line-by-line parsing for legacy format
        raw_output
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.reduce_while({:ok, []}, &parse_and_accumulate/2)
        |> case do
          {:ok, events} -> {:ok, build_test_run_from_events(Enum.reverse(events))}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec parse_json_line(String.t()) :: {:ok, json_event()} | {:error, parse_error()}
  def parse_json_line(json_line) do
    with {:ok, [event_type, data]} <- Jason.decode(json_line),
         {:ok, parsed_event} <- parse_event_type(event_type, data) do
      {:ok, parsed_event}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:invalid_json, %{line: json_line, reason: error}}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec build_test_run_from_events([json_event()], map()) :: TestRun.t()
  def build_test_run_from_events(events, metadata \\ %{}) do
    processed =
      process_events(events, %{
        results: [],
        stats: nil,
        start_data: %{including: [], excluding: []},
        metadata: metadata
      })

    %TestRun{
      project_path: Map.get(metadata, :project_path, ""),
      command: Map.get(metadata, :command, ""),
      exit_code: Map.get(metadata, :exit_code, 0),
      execution_status: Map.get(metadata, :execution_status, :success),
      seed: nil,
      including: processed.start_data.including,
      excluding: processed.start_data.excluding,
      raw_output: Map.get(metadata, :raw_output, ""),
      executed_at: Map.get(metadata, :executed_at, NaiveDateTime.utc_now()),
      stats: processed.stats,
      results: Enum.reverse(processed.results)
    }
  end

  defp parse_and_accumulate(line, {:ok, acc}) do
    case parse_json_line(line) do
      {:ok, event} -> {:cont, {:ok, [event | acc]}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp parse_event_type("start", %{"including" => inc, "excluding" => exc}) do
    {:ok, {:start, %{including: inc || [], excluding: exc || []}}}
  end

  defp parse_event_type("start", _data) do
    {:ok, {:start, %{including: [], excluding: []}}}
  end

  defp parse_event_type("pass", %{"title" => title, "fullTitle" => full_title}) do
    {:ok, {:pass, %{title: title, full_title: full_title}}}
  end

  defp parse_event_type("fail", %{"title" => title, "fullTitle" => full_title, "err" => err}) do
    {:ok, {:fail, %{title: title, full_title: full_title, err: err}}}
  end

  defp parse_event_type("end", stats_data) do
    {:ok, {:end, stats_data}}
  end

  defp parse_event_type(unknown_type, data) do
    {:error, {:unknown_event, %{type: unknown_type, data: data}}}
  end

  defp process_events([], acc), do: acc

  defp process_events([{:start, data} | rest], acc) do
    process_events(rest, %{acc | start_data: data})
  end

  defp process_events([{:pass, data} | rest], acc) do
    result = %TestResult{
      title: data.title,
      full_title: data.full_title,
      status: :passed,
      error: nil
    }

    process_events(rest, %{acc | results: [result | acc.results]})
  end

  defp process_events([{:fail, data} | rest], acc) do
    error = parse_test_error(data.err)

    result = %TestResult{
      title: data.title,
      full_title: data.full_title,
      status: :failed,
      error: error
    }

    process_events(rest, %{acc | results: [result | acc.results]})
  end

  defp process_events([{:end, data} | rest], acc) do
    stats = parse_test_stats(data)
    process_events(rest, %{acc | stats: stats})
  end

  defp parse_test_error(%{"file" => file, "line" => line, "message" => message}) do
    %TestError{
      file: file,
      line: line,
      message: message
    }
  end

  defp parse_test_error(%{"message" => message}) do
    %TestError{
      file: nil,
      line: nil,
      message: message
    }
  end

  defp parse_test_error(data) do
    %TestError{
      file: nil,
      line: nil,
      message: inspect(data)
    }
  end

  defp parse_test_stats(data) do
    %TestStats{
      duration_ms: round(Map.get(data, "duration", 0.0)),
      load_time_ms: data["loadTime"] && round(data["loadTime"]),
      passes: Map.get(data, "passes", 0),
      failures: Map.get(data, "failures", 0),
      pending: Map.get(data, "pending", 0),
      invalid: Map.get(data, "invalid", 0),
      tests: Map.get(data, "tests", 0),
      suites: Map.get(data, "suites", 0),
      started_at: parse_datetime(Map.get(data, "start")),
      finished_at: parse_datetime(Map.get(data, "end"))
    }
  end

  defp parse_datetime(nil), do: NaiveDateTime.utc_now()

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case NaiveDateTime.from_iso8601(datetime_string) do
      {:ok, datetime} -> datetime
      {:error, _} -> NaiveDateTime.utc_now()
    end
  end

  defp parse_datetime(_), do: NaiveDateTime.utc_now()

  # Parse ExUnitJsonFormatter output (single JSON object with modules array)
  defp parse_exunit_json_formatter(raw_output) do
    # Extract JSON from output (skip compilation messages)
    case Regex.run(~r/(\{.*\})/s, raw_output) do
      [_, json_part] ->
        case Jason.decode(json_part) do
          {:ok, %{"modules" => modules}} ->
            results = parse_modules_to_results(modules)
            stats = calculate_stats_from_results(results)
            
            test_run = %TestRun{
              project_path: "",
              command: "",
              exit_code: 0,
              execution_status: :success,
              seed: nil,
              including: [],
              excluding: [],
              raw_output: raw_output,
              executed_at: NaiveDateTime.utc_now(),
              stats: stats,
              results: results
            }
            
            {:ok, test_run}
            
          {:ok, _} ->
            {:error, :invalid_format}
            
          {:error, reason} ->
            {:error, {:json_decode_error, reason}}
        end
        
      nil ->
        {:error, :no_json_found}
    end
  end

  defp parse_modules_to_results(modules) when is_list(modules) do
    modules
    |> Enum.flat_map(fn module ->
      module
      |> Map.get("test", [])
      |> Enum.map(&parse_test_to_result/1)
    end)
  end

  defp parse_test_to_result(test) do
    status = case Map.get(test, "state") do
      "passed" -> :passed
      "failed" -> :failed
      _ -> :unknown
    end

    error = if status == :failed do
      # ExUnitJsonFormatter doesn't provide detailed error info in this format
      %TestError{
        file: Map.get(test, "file"),
        line: Map.get(test, "line"),
        message: "Test failed"
      }
    else
      nil
    end

    %TestResult{
      title: Map.get(test, "name", ""),
      full_title: "#{Map.get(test, "module", "")}: #{Map.get(test, "name", "")}",
      status: status,
      error: error
    }
  end

  defp calculate_stats_from_results(results) do
    passes = Enum.count(results, &(&1.status == :passed))
    failures = Enum.count(results, &(&1.status == :failed))
    total = length(results)

    %TestStats{
      duration_ms: 0,
      load_time_ms: nil,
      passes: passes,
      failures: failures,
      pending: 0,
      invalid: 0,
      tests: total,
      suites: 1,
      started_at: NaiveDateTime.utc_now(),
      finished_at: NaiveDateTime.utc_now()
    }
  end
end
