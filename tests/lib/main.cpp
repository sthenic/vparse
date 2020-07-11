#include "../../include/vparse.h"

#include "CppUTest/CommandLineTestRunner.h"
#include <unistd.h>

TEST_GROUP(Main)
{
};

TEST(Main, MissingFile)
{
    struct vparse_graph *graph = NULL;
    int result = vparse_open_graph("", NULL, 0, NULL, 0, &graph);
    LONGS_EQUAL(VPARSE_EIO, result);
}

TEST(Main, NullHandle)
{
    int result = vparse_open_graph("", NULL, 0, NULL, 0, NULL);
    LONGS_EQUAL(VPARSE_EINVAL, result);
}

TEST(Main, OpenGraphCheckForErrors)
{
    struct vparse_graph *graph = NULL;
    const char filename[] = "src/src3.v";
    const char *include_paths[] = {};
    const char *defines[] = {};

    int result = vparse_open_graph(filename, include_paths,
                                   sizeof(include_paths) / sizeof(*include_paths), defines,
                                   sizeof(defines) / sizeof(*defines), &graph);
    LONGS_EQUAL(VPARSE_EOK, result);
    LONGS_EQUAL(0, vparse_ast_has_errors(graph));

    vparse_close_graph(graph);
}

TEST(Main, FindIdentifier)
{
    struct vparse_graph *graph = NULL;
    const char filename[] = "src/src3.v";
    int result = vparse_open_graph(filename, NULL, 0, NULL, 0, &graph);
    LONGS_EQUAL(VPARSE_EOK, result);

    struct vparse_node *identifier = NULL;
    LONGS_EQUAL(VPARSE_EOK, vparse_find_identifier(graph, 33, 19, 0, &identifier, NULL));

    const char *identifier_str = NULL;
    LONGS_EQUAL(VPARSE_EOK, vparse_get_identifier(identifier, &identifier_str));
    STRCMP_EQUAL("a_common_wire", identifier_str);

    vparse_close_graph(graph);
}

TEST(Main, FindIdentifierNoMatch)
{
    struct vparse_graph *graph = NULL;
    const char filename[] = "src/src3.v";
    int result = vparse_open_graph(filename, NULL, 0, NULL, 0, &graph);
    LONGS_EQUAL(VPARSE_EOK, result);

    struct vparse_node *identifier = NULL;
    LONGS_EQUAL(VPARSE_EOK, vparse_find_identifier(graph, 33, 18, 0, &identifier, NULL));
    POINTERS_EQUAL(NULL, identifier);
    vparse_close_graph(graph);
}

TEST(Main, FindDeclarationSelectIdentifier)
{
    struct vparse_graph *graph = NULL;
    const char filename[] = "src/src3.v";
    int result = vparse_open_graph(filename, NULL, 0, NULL, 0, &graph);
    LONGS_EQUAL(VPARSE_EOK, result);

    struct vparse_node *identifier = NULL;
    struct vparse_context *context = NULL;
    LONGS_EQUAL(VPARSE_EOK, vparse_find_identifier(graph, 42, 46, 0, &identifier, &context));

    const char *identifier_str = NULL;
    LONGS_EQUAL(VPARSE_EOK, vparse_get_identifier(identifier, &identifier_str));
    STRCMP_EQUAL("a_local_wire", identifier_str);

    struct vparse_node *declaration = NULL;
    LONGS_EQUAL(VPARSE_EOK, vparse_find_declaration(graph, context, identifier, 1, &declaration, NULL));

    int file, line, col;
    LONGS_EQUAL(VPARSE_EOK, vparse_get_location(declaration, &file, &line, &col));
    LONGS_EQUAL(1, file);
    LONGS_EQUAL(40, line);
    LONGS_EQUAL(17, col);

    vparse_close_graph(graph);
}

TEST(Main, FindAllDeclarations)
{
    struct vparse_graph *graph = NULL;
    const char filename[] = "src/src3.v";
    int result = vparse_open_graph(filename, NULL, 0, NULL, 0, &graph);
    LONGS_EQUAL(VPARSE_EOK, result);

    struct vparse_node **declarations = NULL;
    size_t declarations_len = 0;
    LONGS_EQUAL(VPARSE_EOK, vparse_find_all_declarations(graph, 1, &declarations, &declarations_len));
    LONGS_EQUAL(25, declarations_len);
    vparse_close_graph(graph);
}

TEST(Main, FindReferences)
{
    struct vparse_graph *graph = NULL;
    const char filename[] = "src/src3.v";
    int result = vparse_open_graph(filename, NULL, 0, NULL, 0, &graph);
    LONGS_EQUAL(VPARSE_EOK, result);

    struct vparse_node *identifier = NULL;
    LONGS_EQUAL(VPARSE_EOK, vparse_find_identifier(graph, 20, 16, 0, &identifier, NULL));

    struct vparse_node **references = NULL;
    size_t references_len = 0;
    LONGS_EQUAL(VPARSE_EOK, vparse_find_references(graph, identifier, &references, &references_len));
    LONGS_EQUAL(6, references_len);
    vparse_close_graph(graph);
}

int main(int argc, const char *argv[])
{
    vparse_init();
    return CommandLineTestRunner::RunAllTests(argc, argv);
}
