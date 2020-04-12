# Copyright (C) Marcus Eriksson 2020
#
# Description: This file implements the graph for a Verilog source tree.
# TODO: Describe an overview of the the implementation.

import streams

import ./parser
export parser

type
   Graph* = object
      parser: Parser
      file_index: ref seq[string]


proc open_graph*(g: var Graph, cache: IdentifierCache, s: Stream,
                 filename: string) =
   new g.file_index
   g.file_index[] = new_seq_of_cap[string](32)
   open_parser(g.parser, cache, s, filename, g.file_index)


proc close_graph*(g: var Graph) =
   close_parser(g.parser)


proc parse_all*(g: var Graph): PNode =
   result = parse_all(g.parser)
