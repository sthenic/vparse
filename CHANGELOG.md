# CHANGELOG

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- Add interface `find_all_drivers()` to simplify extracting driver nodes from
  the AST.
- Add interface `find_all_ports()` and `find_all_parameters()`.
- Add a set for the node types involved in expressions.
- Add the option to specify the start of the search for the various
  `find_first()` functions.

## Fixed

- Disable colored output when stdout does not lead to a terminal.

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
