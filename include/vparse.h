#ifndef VPARSE_H_S8NRAS
#define VPARSE_H_S8NRAS

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

#define VPARSE_EOK (0)
#define VPARSE_EINVAL (-1)
#define VPARSE_EIO (-2)

/* Anonymous struct declarations. */
struct vparse_graph;
struct vparse_node;
struct vparse_context;

/* Initialize the library. */
int vparse_init(void);

/* Open a graph. */
int vparse_open_graph(const char *filename,
                      const char **include_paths, size_t include_paths_len,
                      const char **defines, size_t defines_len,
                      struct vparse_graph **graph);

/* Close the graph. */
void vparse_close_graph(struct vparse_graph *graph);

/* Dump the AST to stdout. */
int vparse_ast_print(struct vparse_graph *graph);

/* Check if the AST contains errors. */
int vparse_ast_has_errors(struct vparse_graph *graph);

/* Extract the identifier as a string. The node has to be an identifier type. */
int vparse_get_identifier(struct vparse_node *node, const char **identifier);

/* Extract the location of a node. */
int vparse_get_location(struct vparse_node *node, int *file, int *line, int *col);

/* Find the identifier at the target location. */
int vparse_find_identifier(struct vparse_graph *graph, int line, int col, int added_length,
                           struct vparse_node **identifier,
                           struct vparse_context **context);

/* Find the declaration of the target identifier. */
int vparse_find_declaration(struct vparse_graph *graph,
                            struct vparse_context *context,
                            struct vparse_node *identifier, int select_identifier,
                            struct vparse_node **declaration,
                            struct vparse_context **declaration_context);

/* Find the declaration of the target identifier. */
int vparse_find_all_declarations(struct vparse_graph *graph,
                                 int select_identifier,
                                 struct vparse_node ***declarations,
                                 size_t *declarations_len);

/* Find all references to the target identifier. */
int vparse_find_references(struct vparse_graph *graph,
                           struct vparse_node *identifier,
                           struct vparse_node ***references,
                           size_t *references_len);

#ifdef __cplusplus
}
#endif
#endif
