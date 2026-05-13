defmodule Guppy.PackageTest do
  use ExUnit.Case, async: true

  test "mix project declares shippable source-build package metadata" do
    config = Mix.Project.config()

    assert is_binary(config[:description])
    assert String.contains?(config[:description], "GPUI")

    package = config[:package]
    assert is_list(package[:licenses]) and package[:licenses] != []
    assert is_map(package[:links]) and map_size(package[:links]) > 0

    files = package[:files]
    assert "lib" in files
    assert "mix.exs" in files
    assert "README.md" in files
    assert "LICENSE" in files
    assert "CHANGELOG.md" in files
    assert "native/guppy_nif/src" in files
    assert "native/guppy_nif/Cargo.toml" in files
    assert "native/guppy_nif/Cargo.lock" in files
    assert "native/guppy_nif/build.rs" in files

    refute Enum.any?(files, &String.starts_with?(&1, "priv/native"))
    refute Enum.any?(files, &String.contains?(&1, "native/guppy_nif/target"))
  end

  test "package smoke script exists for generated Hex package contents" do
    assert File.exists?(Path.expand("../../scripts/package_smoke", __DIR__))
  end
end
