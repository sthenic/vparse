#ifndef VPARSE_H_S8NRAS
#define VPARSE_H_S8NRAS

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

#define VPARSE_EOK (0)
#define VPARSE_EINVAL (-1)
#define VPARSE_EIO (-2)

struct vparse_graph;

int vparse_open_graph(const char *filename,
                      const char **include_paths, size_t include_paths_len,
                      const char **defines, size_t defines_len,
                      struct vparse_graph **graph);

void vparse_close_graph(struct vparse_graph *graph);

int vparse_print_root(struct vparse_graph *graph);


#ifdef __cplusplus
}
#endif
#endif
