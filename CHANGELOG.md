# CHANGELOG

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- Fix a crash that could happen when the parser encountered invalid syntax for a
  hierarchical identifier.

## [v0.3.1] - 2020-11-28

### Fixed

- Support the syntax `` `WIDTH'hF0``, i.e. where the *size* specifier of a sized
  integer literal is the result of a macro expansion. Many parsers seem to
  support this syntax even though the standard appears to define this as not
  legal Verilog since macros are not allowed to break number tokens.

## [v0.3.0] - 2020-11-25

### Changed

- Require Nim v1.4.0.
- The returned tuple for the `find_declaration()` procedure now includes any
  expression node if the declaration involves an assignment. Otherwise, this
  field is set to `nil`.
- Ranged expressions with `:` is now an infix node.
- Refactored the module graph type (`graph.nim`) and its interface.

  Parsing a Verilog source file now involves attempting to look up the
  declarations of all modules instantiated within.
- Refactored the iterators `walk_ports()` and `walk_parameters()` to simplify
  logic in user applications.

### Added

- Add module caching. The user has to manage the module cache and location
  database and initialize each new module graph with these objects. See
  `graph.nim:new_graph()`.
- Add interface `find_all_drivers()` to simplify extracting driver nodes from
  the AST.
- Add interface `find_all_ports()` and `find_all_parameters()`.
- Add a set for the node types involved in expressions.
- Add the option to specify the start of the search for the various
  `find_first()` functions.
- Add operators `[]` and `[]=` to AST nodes. This is shorthand to access the
  sequence of sons for nonprimitive nodes, i.e. `n[i]` is equivalent to
  `n.sons[i]`.
- Define the `len()` proc for nonprimitive AST nodes. The operation is
  equivalent to `len(n.sons)`.
- For completeness, performing a declaration lookup with a module instance name
  leads back to the instantiation itself.
- Add `is_external_identifier()` to the AST API.
- Add `find_external_identifier()`, `find_module_port_declaration()` and
  `find_module_parameter_declaration()` to the module graph API.
- Add the iterator `walk_port_references()`.
- Module declaration nodes now include the leading comment token.
- An include path ending with '**' implies a recursive include.

### Fixed

- Disable colored output when stdout does not lead to a terminal.
- Fix `find_all_parameters()` always including the parameters declared in the
  module body. Like ports, these only get included if the parameter port list is
  omitted.
- Fix an issue where the lexer would throw an exception when parsing a decimal
  constant larger than 64 bits.
- Hierarchical identifiers like `foo.bar[1].baz[3:0]` are now supported.
  Previously, only ranged identifiers was allowed and the scoping syntax with
  `.` didn't work.
- Fix an issue where operators were not being lexed correctly.

  The issue occurred when a an infix operator was immediately followed by a
  prefix operator, i.e. not separated by whitespace. Before this fix an
  expression like `a|~b` would be lexed as `a`, `|~` and `b` instead of `a`,
  `|`, `~` and `b` like it should.
- Fix `find_declaration()` not yielding the declaration when the target
  identifier is a port reference.

### Removed

- Remove AST nodes `NkVariableLvalue` and `NkArrayIdentifier`.
- Remove special identifier node types like `NkPortIdentifier` and
  `NkModuleIdentifier` in favor of the generic `NkIdentifier`.
- Remove `NkParameterAssignment`, use `NkAssignment` instead.

## [v0.2.2] - 2020-08-31

### Fixed

- Fix an issue where the preprocessor would remove comments located immediately
  after the token that ends the replacement list.
- Fix localparam and parameter declarations not including the leading comment
  token.

## [v0.2.1] - 2020-08-30

### Fixed

- Fix stringification of concatenation nodes.

## [v0.2.0] - 2020-08-24

### Fixed

- Fix `find_identifier_physical()` not working correctly when targeting macro
  arguments.
- `find_references()` now correctly ignores named parameter port connections.

### Changed

- The interface to traverse the AST searching for the declaration of a target
  identifier now returns both the declaration node as well as the matching
  identifier node within the declaration. Previously, only one of these values
  was returned.
- `find_all_module_instantiations()` now returns the top-level instantiation
  node instead of its identifer node.
- `find_all_declarations()` no longer performs a recursive search by default.
- Remove `NkPortConnection` in favor of more specialized node types for port and
  parameter port connections.

## [v0.1.1] - 2020-08-10

### Fixed

- Fix stringification of task and function declarations (the type information
  was omitted in the output).

## [v0.1.0] - 2020-08-08

- This is the first release of the project.
