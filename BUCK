# A list of available rules and their signatures can be found here: https://buck2.build/docs/api/rules/

cxx_binary(
    name = "use_c",
    srcs = ["use.c"],
    deps = [
        "//tree-sitter-balanced:tree-sitter-balanced",
        "//tree-sitter/lib:c",
   ]
)

rust_binary(
    name = "use_rs",
    srcs = ["use.rs"],
    crate_root = "use.rs",
    edition = "2021",
    deps = [
        "//tree-sitter/lib:rust",
        "//tree-sitter-balanced:rust",
    ],
)