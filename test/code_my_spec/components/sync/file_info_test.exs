defmodule CodeMySpec.Components.Sync.FileInfoTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.Components.Sync.FileInfo

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "file_info_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "from_path/1" do
    test "returns FileInfo struct with correct path", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "test_file.ex")
      File.write!(file_path, "defmodule Test do\nend")

      result = FileInfo.from_path(file_path)

      assert %FileInfo{} = result
      assert result.path == file_path
    end

    test "mtime is a UTC DateTime", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "test_file.ex")
      File.write!(file_path, "defmodule Test do\nend")

      result = FileInfo.from_path(file_path)

      assert %DateTime{} = result.mtime
      assert result.mtime.time_zone == "Etc/UTC"
    end

    test "raises on non-existent file" do
      assert_raise File.Error, fn ->
        FileInfo.from_path("/nonexistent/path/to/file.ex")
      end
    end
  end

  describe "collect_files/2" do
    test "returns list of FileInfo structs", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "one.ex"), "")
      File.write!(Path.join(tmp_dir, "two.ex"), "")

      result = FileInfo.collect_files(tmp_dir, "*.ex")

      assert is_list(result)
      assert length(result) == 2
      assert Enum.all?(result, &match?(%FileInfo{}, &1))
    end

    test "each struct has correct path and mtime", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "sample.ex")
      File.write!(file_path, "")

      [file_info] = FileInfo.collect_files(tmp_dir, "*.ex")

      assert file_info.path == file_path
      assert %DateTime{time_zone: "Etc/UTC"} = file_info.mtime
    end

    test "returns empty list when no files match", %{tmp_dir: tmp_dir} do
      result = FileInfo.collect_files(tmp_dir, "*.nonexistent")

      assert result == []
    end
  end
end
