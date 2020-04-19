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
      locations: PLocations


proc open_graph*(g: var Graph, cache: IdentifierCache, s: Stream,
                 filename: string) =
   new g.locations
   init(g.locations)
   open_parser(g.parser, cache, s, filename, g.locations)


proc close_graph*(g: var Graph) =
   close_parser(g.parser)


proc parse_all*(g: var Graph): PNode =
   result = parse_all(g.parser)
