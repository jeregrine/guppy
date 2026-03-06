defmodule Mix.Tasks.Guppy.Native.Build do
  @shortdoc "Builds and installs the Guppy native NIF library"

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [release: :boolean])

    profile = if opts[:release], do: "release", else: "debug"
    project_root = File.cwd!()
    native_dir = Path.join(project_root, "native/guppy_nif")
    priv_dir = Path.join(project_root, "priv/native")
    destination = Path.join(priv_dir, "guppy_nif#{beam_nif_extension()}")

    Mix.shell().info("Building guppy_nif (#{profile})")

    cargo_args = ["build"] ++ if(opts[:release], do: ["--release"], else: [])

    case System.cmd("cargo", cargo_args, cd: native_dir, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        File.mkdir_p!(priv_dir)

        source = Path.join([native_dir, "target", profile, cargo_library_filename()])
        File.cp!(source, destination)

        Mix.shell().info("Installed #{destination}")

      {output, status} ->
        Mix.raise("cargo build failed with status #{status}\n\n#{output}")
    end
  end

  defp cargo_library_filename do
    base = "libguppy_nif"

    case :os.type() do
      {:win32, _} -> "guppy_nif.dll"
      {:unix, :darwin} -> base <> ".dylib"
      {:unix, _} -> base <> ".so"
    end
  end

  defp beam_nif_extension do
    case :os.type() do
      {:win32, _} -> ".dll"
      _ -> ".so"
    end
  end
end
