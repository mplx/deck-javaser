# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * Decode Java Object Serialization streams: what `ObjectOutputStream`
 * writes, found in `.ser` files, caches, session stores and RMI traffic.
 * The stream protocol (version 5, Java 1.2 and later) is read in full -
 * class descriptors, objects, arrays, strings, enums, `Class` objects,
 * dynamic proxies, back-references, custom `writeObject` /
 * `writeExternal` data, resets - into a `Stream` of numbered nodes, read
 * with accessors. No Java code runs, so a hostile stream is data, not a
 * deserialization exploit.
 *
 * Nodes are ints: `contents` gives the top-level values, `field` /
 * `custom` / `elements` lead to children, `typeOf` / `className` say what
 * a node is, and `asInt` / `asString` / `asBytes` / `ints` / ... read
 * values. A value written once and referenced again is one node. `dump`
 * prints the whole graph as a tree.
 *
 * Every failure is `Error{kind: "javaser"}`, except a reached cap
 * (`Options.maxNodes`, `Options.maxDepth`), which is kind `"limit"`.
 *
 * | topic | covers |
 * | --- | --- |
 * | `stream` | `decode`, `decodeWith`, `locate`, `Options`, `Stream` |
 * | `values` | the accessors |
 * | `dump` | `dump`, `dumpWith` |
 *
 * @module javaser
 * @example
 *   import "@mplx/javaser/" as javaser;
 *
 *   def s as javaser.Stream init javaser.decode(fs.readBytes("list.ser"));
 *   def list as int init javaser.contents($s)[0];
 *   io.printf("%s of %d\n", javaser.className($s, $list),
 *       javaser.asInt($s, javaser.field($s, $list, "size")));
 */
use binary;
use convert;
use encoding;
use io;
use lists;
use strings;

include "topics/stream.j";
include "topics/values.j";
include "topics/dump.j";
