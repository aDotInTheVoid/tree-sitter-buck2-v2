use tree_sitter::Parser;

fn main() {
    let mut parser = Parser::new();
    parser
        .set_language(tree_sitter_balanced::language())
        .unwrap();
    let code = "{{[]()}}";
    let parsed = parser.parse(code, None).unwrap();
    dbg!(parsed.root_node().to_sexp());
}
