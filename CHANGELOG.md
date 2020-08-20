# CHANGELOG

All notable changes to this project will be documented in this file.

## [Unreleased]

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
