<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

A reader for the Java™ Object Serialization Stream Protocol, version 5, as
specified in chapter 6 of the Java Object Serialization Specification:
every grammar element, nothing class-specific. It turns a stream into a
graph of values and leaves the meaning of a class's custom data to the
program that knows the class; a reader for one application's files is a
separate deck built on this one.

Out of scope: writing streams (rarely needed, and a correct writer has to
reproduce Java's handle and block rules exactly), protocol version 1
externalizable data (the JDK™ has written version 2 by default since 1.2 and
version 1 data cannot be skipped without the class), and anything that
would run code.

## Decisions

- **Nodes, not structs.** Values are numbered nodes over plain lists in one
  `Stream`. A value tree of the deck's own structs would be rebuilt every
  time it crosses into the module, and Java graphs share objects and can
  be cyclic, which a value-semantic tree cannot express. A back-reference is
  the same node number.
- **No recursion per object.** The parser keeps an explicit stack of
  frames. A linked list written by Java nests one object per element, and
  5000 elements would exceed the interpreter's call depth. Only class
  descriptors recurse (superclass chain, annotations), which is bounded by
  class hierarchies.
- **The parser moves, never copies.** Every internal function takes the
  parser and returns it (`$p = f($p)`), and no call passes a parser field
  alongside the parser, so the interpreter moves it instead of copying a
  multi-megabyte value per step (`jennifer profile --allocs` shows none).
- **Block data is joined.** `ObjectOutputStream` cuts primitive data into
  blocks of at most 1024 bytes at arbitrary points, even inside a `long`.
  Adjacent blocks of the same class become one node; a block is what the
  class wrote between two objects. Pieces are kept as offsets into the
  input and joined when read.
- **Class descriptors are not nodes** unless they appear as values
  (`TC_CLASSDESC` in a content position). Classes are numbered separately.
- **Text.** Strings are modified UTF-8. The common case is valid UTF-8 and
  takes the fast path; NUL (`C0 80`) and supplementary characters
  (surrogate pairs) take a slow path. A surrogate without its pair has no
  Jennifer representation and becomes U+FFFD.
- **Floats.** NaN and the infinities have no Jennifer value. They decode
  without error; `asFloat` refuses them and `floatBits` returns the bits.
- **A writer's exception** (`TC_EXCEPTION`, written when serialization failed
  midway) ends decoding with an error naming the exception class and its
  `detailMessage`; what precedes it is incomplete by definition.
- **Proxies** get the class name `$Proxy` (the stream does not carry the
  generated name) and keep their interfaces.

## Errors

`Error{kind: "javaser"}` for malformed or truncated input, invalid options,
an aborted stream and accessor misuse. `"limit"` when `Options.maxNodes` or
`Options.maxDepth` is reached. Messages name the byte offset where decoding
stopped.

## Security and limits

Decoding a stream runs no code: classes are names, not loaded types, so
gadget-chain payloads are inert data. Hostile input is bounded by the input
size (every length is checked against the bytes left before anything is
allocated) and by `maxNodes` / `maxDepth`. A superclass chain that loops
through a back-reference is detected. Class annotations recurse; a stream
that nests class descriptors inside annotations thousands deep ends in the
interpreter's catchable `"limit"` error.

## Testing and validation

The overlays decode streams written by OpenJDK™ 17's `ObjectOutputStream`
(`testdata/gen/Fixtures.java`, embedded by `testdata/gen/embed.j` because
jvc runs the overlays from a copy of `src/` alone): every primitive type,
NaN and infinities, every array type, nested and object arrays, strings with
NUL, emoji and CJK, a 70,000-character long string, back-references,
`writeObject` data past 1024 bytes, `Externalizable`, shadowed fields,
enums, `Class` objects, `HashMap` / `Integer` / `Date`, a dynamic proxy,
a reset, top-level primitive writes, a 5000-element linked list and an
aborted stream. Malformed input is built from hex in the tests.

Outside the suite, a 2.9 MB application project file (38,480 nodes)
decodes in about 5 s.

## Known limitations and open questions

- Protocol version 1 externalizable data is refused.
- Decoding speed is a few hundred kilobytes per second; very large streams
  take a while.
- `dump` indents by depth, so a deep chain dumps quadratically large text.

## Dependencies on the interpreter

`>=0.28.0`: the `binary` number readers, `binary.indexOf`, `compress` in
the overlays, `time.fromUnixMilliseconds` in the examples, and module structs
passed into the deck without a rebuild per call (a `Stream` accessor costs the
same as a local call). Pure computation, no capabilities. Not checked on
`jennifer-tiny`.
