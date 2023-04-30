#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <tree_sitter/api.h>

TSLanguage *tree_sitter_balanced();

int main() {
  TSParser *parser = ts_parser_new();
  ts_parser_set_language(parser, tree_sitter_balanced());

  const char *source_code = "[](){[]{}()}(())";

  TSTree *tree =
      ts_parser_parse_string(parser, NULL, source_code, strlen(source_code));

  TSNode root_node = ts_tree_root_node(tree);
  char *string = ts_node_string(root_node);
  printf("Syntax tree: %s\n", string);
}
