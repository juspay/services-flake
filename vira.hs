-- CI configuration <https://vira.nixos.asia/>
\ctx pipeline ->
  let
    isMaster = ctx.branch == "main"
  in pipeline
     { build.systems =
        [ "x86_64-linux"
        , "aarch64-darwin"
        ]
     , build.flakes =
         [ "./example/simple" { overrideInputs = [("services-flake", ".")] }
         , "./example/llm" { overrideInputs = [("services-flake", ".")] }
         , "./example/share-services/pgweb" { overrideInputs = [("services-flake", "."), ("northwind", "path:./example/share-services/northwind")] }
         , "./example/without-flake-parts" { overrideInputs = [("services-flake", ".")] }
         , "./test" { overrideInputs = [("services-flake", ".")] }
         , "./dev" { overrideInputs = [("services-flake", ".")] }
         , "./doc"
         ]
     , signoff.enable = True
     , cache.url = if isMaster then Just "https://cache.nixos.asia/oss" else Nothing
     }
