# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements the graph for a Verilog source tree.
# TODO: Describe an overview of the the implementation.

import streams

import ./parser
import ./location
export parser

type
   Graph* = object
      parser: Parser
      locations*: PLocations
      root_node*: PNode


proc open_graph*(g: var Graph, cache: IdentifierCache, s: Stream,
                 filename: string, include_paths: openarray[string],
                 external_defines: openarray[string]) =
   new g.locations
   init(g.locations)
   open_parser(g.parser, cache, s, filename, g.locations, include_paths,
               external_defines)
   g.root_node = parse_all(g.parser)


proc close_graph*(g: var Graph) =
   close_parser(g.parser)


proc parse_all*(g: var Graph): PNode =
   result = g.root_node
