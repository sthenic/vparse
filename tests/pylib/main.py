import sys
from os import path
sys.path.append(path.dirname(path.dirname(path.abspath(__file__ + "../.."))))
import vparse as vp

if __name__ == "__main__":
    try:
        graph = vp.open_graph("../lib/src/src3.v", [], [])
    except vp.NimPyException as e:
        quit(-1)

    root = vp.get_root_node(graph)
    print("Walking over the nodes:")
    for i, module in enumerate(vp.walk_module_declarations(root)):
        print("Module {}".format(i))
        for j, port in enumerate(vp.walk_ports(module)):
            print("Port {}: {} {} {}".format(j, vp.get_direction(port), vp.get_net_type(port), vp.get_identifier(port)))
        for j, port in enumerate(vp.walk_parameter_ports(module)):
            print("Parameter {}".format(j))

    print("Has errors: {}".format(vp.has_errors(root)))

    vp.close_graph(graph)
