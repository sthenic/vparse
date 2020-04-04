# This file defines an array containing the protected keywords of the language.
# The array must be kept sorted and in sync with the keyword token section in
# the lexer.

const
   SpecialWords* = ["",
      # Keywords
      "always", "and", "assign", "automatic",
      "begin", "buf", "bufif0", "bufif1",
      "case", "casex", "casez", "cell", "cmos", "config",
      "deassign", "default", "defparam", "design", "disable",
      "edge", "else",
      "end", "endcase", "endconfig", "endfunction", "endgenerate", "endmodule",
      "endprimitive", "endspecify", "endtable", "endtask", "event",
      "for", "force", "forever", "fork", "function",
      "generate", "genvar",
      "highz0", "highz1",
      "if", "ifnone", "incdir", "include", "initial", "inout", "input",
      "instance", "integer",
      "join",
      "large", "liblist", "library", "localparam",
      "macromodule", "medium", "module",
      "nand", "negedge", "nmos", "nor", "noshowcancelled",
      "not", "notif0", "notif1",
      "or", "output",
      "parameter", "pmos", "posedge", "primitive", "pull0",
      "pull1", "pulldown", "pullup", "pulsestyle_ondetect", "pulsestyle_onevent",
      "rcmos", "real", "realtime", "reg", "release", "repeat", "rnmos", "rpmos",
      "rtran", "rtranif0", "rtranif1",
      "scalared", "showcancelled", "signed", "small", "specify", "specparam",
      "strong0", "strong1", "supply0", "supply1",
      "table", "task", "time", "tran", "tranif0", "tranif1", "tri",
      "tri0", "tri1", "triand", "trior", "trireg",
      "use",
      "vectored",
      "wait", "wand", "weak0", "weak1", "while", "wire", "wor",
      "xnor", "xor",
      # Special characters
      "\\", ",", ".", "?", ";", ":", "@", "#", "(", ")", "[", "]", "{", "}",
      "(*", "*)", "+:", "-:", "->", "="
   ]