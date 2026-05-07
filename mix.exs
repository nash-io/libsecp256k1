unless Code.ensure_loaded?(Mix.Tasks.Compile.MakeBindings) do
  defmodule Mix.Tasks.Compile.MakeBindings do
    use Mix.Task

    def run(_) do
      {_, exit_code} = System.cmd("make", ["-j4"], into: IO.stream(:stdio, :line))

      case exit_code do
        0 -> :ok
        _ -> :error
      end
    end
  end
end

unless Code.ensure_loaded?(Mix.Tasks.Eunit) do
  defmodule Mix.Tasks.Eunit do
    use Mix.Task

    @shortdoc "Runs Erlang eunit tests"

    def run(args) do
      Mix.Task.run("compile")

      File.mkdir_p!(".eunit")
      :code.add_patha(String.to_charlist(Path.expand(".eunit")))
      :code.add_patha(String.to_charlist(Path.join(eunit_dir!(), "ebin")))

      tests =
        Path.wildcard("etest/**/*_tests.erl")
        |> Enum.map(&compile_test!/1)

      options =
        args
        |> Enum.filter(&(&1 in ["-v", "--verbose"]))
        |> Enum.map(fn _ -> :verbose end)

      case :eunit.test(tests, options) do
        :ok -> :ok
        :error -> Mix.raise("eunit tests failed")
      end
    end

    defp compile_test!(path) do
      include_dir = String.to_charlist(Path.join(eunit_dir!(), "include"))

      case :compile.file(String.to_charlist(path), [
             {:i, include_dir},
             {:outdir, ~c".eunit"},
             :report_errors,
             :report_warnings
           ]) do
        {:ok, module} -> module
        {:ok, module, _warnings} -> module
        :error -> Mix.raise("failed to compile #{path}")
        {:error, _errors, _warnings} -> Mix.raise("failed to compile #{path}")
      end
    end

    defp eunit_dir! do
      :code.root_dir()
      |> to_string()
      |> Path.join("lib/eunit-*")
      |> Path.wildcard()
      |> List.first()
      |> case do
        nil -> Mix.raise("could not find eunit in the Erlang/OTP installation")
        dir -> dir
      end
    end
  end
end

defmodule Libsecp256k1.Mixfile do
  use Mix.Project

  def project do
    [
      app: :libsecp256k1,
      version: "0.1.15",
      language: :erlang,
      description: "Erlang NIF bindings for the the libsecp256k1 library",
      package: [
        name: "libsecp256k1_nash_fork",
        files: [
          "LICENSE",
          "Makefile",
          "README.md",
          "c_src/libsecp256k1_nif.c",
          "c_src/gmp-6.2.1.tar.xz",
          "c_src/secp256k1.tar.xz",
          "etest/libsecp256k1_tests.erl",
          "mix.exs",
          "priv/.empty",
          "src/libsecp256k1.erl"
        ],
        maintainers: ["Dominic Letz"],
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/nash-io/libsecp256k1",
          "Forked from" => "https://github.com/diodechain/libsecp256k1"
        }
      ],
      compilers: [:make_bindings, :erlang, :app],
      deps: []
    ]
  end
end
