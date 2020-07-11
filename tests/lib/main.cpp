#include "../../include/vparse.h"

#include "CppUTest/CommandLineTestRunner.h"

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

TEST(Main, OpenGraph)
{
    struct vparse_graph *graph = NULL;
    const char filename[] = "src/src3.v";
    const char *include_paths[] = {};
    const char *defines[] = {};

    int result = vparse_open_graph(filename, include_paths,
                                   sizeof(include_paths) / sizeof(*include_paths), defines,
                                   sizeof(include_paths) / sizeof(*defines), &graph);
    LONGS_EQUAL(VPARSE_EOK, result);
    vparse_close_graph(graph);
}

int main(int argc, const char *argv[])
{
    return CommandLineTestRunner::RunAllTests(argc, argv);
}
