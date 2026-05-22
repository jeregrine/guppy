%{
  configs: [
    %{
      name: "default",
      plugins: [{ExSlop, []}],
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: [
        {Credo.Check.Design.AliasUsage, false}
      ]
    }
  ]
}
