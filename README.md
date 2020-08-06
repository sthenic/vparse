[![NIM](https://img.shields.io/badge/Nim-1.2.6-orange.svg?style=flat-square)](https://nim-lang.org)
[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)
![tests](https://github.com/sthenic/vparse/workflows/tests/badge.svg)

# vparse
This tool is a Verilog IEEE 1364-2005 parser library written in
[Nim](https://nim-lang.org). The output is an abstract syntax tree (AST)
intended to be used by other tools to process source files written in Verilog.
For example, [`vls`](https://github.com/sthenic/vls) is a language server
implementation that relies on this library to analyze the source code.

It's also possible to extract the tokenized source code directly from the lexer
or from the preprocessor.

## Documentation
Coming soon.

## Version numbers
Releases follow [semantic versioning](https://semver.org/) to determine how the version number is incremented. If the specification is ever broken by a release, this will be documented in the changelog.

## Reporting a bug
If you discover a bug or what you believe is unintended behavior, please submit an issue on the [issue board](https://github.com/sthenic/vparse/issues). A minimal working example and a short description of the context is appreciated and goes a long way towards being able to fix the problem quickly.

## License
This tool is free software released under the [MIT license](https://opensource.org/licenses/MIT).

## Third-party dependencies

* [Nim's standard library](https://github.com/nim-lang/Nim)

## Author
vparse is maintained by [Marcus Eriksson](mailto:marcus.jr.eriksson@gmail.com).
