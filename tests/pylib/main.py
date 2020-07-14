import sys
from os import path
sys.path.append(path.dirname(path.dirname(path.abspath(__file__ + "../.."))))
import vparse as vp

if __name__ == "__main__":
    try:
        graph = vp.open_graph("./src3.v", [], [])
    except vp.NimPyException as e:
        print(repr(e))
        quit(-1)

    root = vp.get_root_node(graph)
    print("AST: {}", vp.json(root))
    print("Has errors: {}".format(vp.has_errors(root)))
    vp.close_graph(graph)
