<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# javaser cheatsheet

Every export of `@mplx/javaser`. Guides are listed in
[the introduction](index.md).

```jennifer
import "@mplx/javaser/" as javaser;
```

Every failure is `Error{kind: "javaser"}`, except a reached cap
(`Options.maxNodes`, `Options.maxDepth`), which is kind `"limit"`. An `s`
argument is a `Stream`; an `n` argument is a node number. Node 0 is `null`.

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `DEFAULT_MAX_NODES` | `2000000` | `Options.maxNodes` in `defaults()` |
| `DEFAULT_MAX_DEPTH` | `100000` | `Options.maxDepth` in `defaults()` |
| `DUMP_PREVIEW` | `8` | array elements and block bytes `dump` shows |
| `SC_WRITE_METHOD` | `0x01` | class flag: has `writeObject`, custom data follows its fields |
| `SC_SERIALIZABLE` | `0x02` | class flag: `Serializable` |
| `SC_EXTERNALIZABLE` | `0x04` | class flag: `Externalizable`, its data is custom only |
| `SC_BLOCK_DATA` | `0x08` | class flag: externalizable data in block data (protocol 2) |
| `SC_ENUM` | `0x10` | class flag: an enum |

## Decoding

| Function | Returns | Does |
|---|---|---|
| `decode(data)` | `Stream` | decode a stream starting at the first byte, with `defaults()` |
| `decodeWith(data, opts)` | `Stream` | decode with an offset and caps |
| `defaults()` | `Options` | offset 0, `DEFAULT_MAX_NODES`, `DEFAULT_MAX_DEPTH` |
| `locate(data)` | `int` | offset of the first `AC ED 00 05`, -1 when there is none |

## Navigating

| Function | Returns | Does |
|---|---|---|
| `contents(s)` | `list of int` | the top-level values in write order |
| `nodeCount(s)` | `int` | the number of nodes, node 0 included |
| `typeOf(s, n)` | `string` | `null` `object` `array` `string` `enum` `class` `classdesc` `block`, or a primitive type name |
| `className(s, n)` | `string` | the Java™ class name; `""` for nodes without one |
| `classChain(s, n)` | `list of string` | the serializable classes, superclass first |
| `serialVersionUid(s, n)` | `int` | the class's serialVersionUID |
| `interfaces(s, n)` | `list of string` | a dynamic proxy's interfaces |
| `fieldNames(s, n)` | `list of string` | serializable fields, superclass first; shadowed names repeat |
| `has(s, n, name)` | `bool` | whether the object has the field |
| `field(s, n, name)` | `int` | a field's value; the most derived class's when shadowed |
| `fieldOf(s, n, cls, name)` | `int` | a field as one class of the chain declares it |
| `custom(s, n)` | `list of int` | what `writeObject` / `writeExternal` wrote: blocks and objects |
| `customOf(s, n, cls)` | `list of int` | the custom data of one class of the chain |
| `elements(s, n)` | `list of int` | an object array's elements |
| `objectsOf(s, cls)` | `list of int` | every object of a class, in stream order |

## Values

| Function | Returns | Does |
|---|---|---|
| `asInt(s, n)` | `int` | a `byte`, `short`, `int`, `long`, or a `char`'s code unit |
| `asFloat(s, n)` | `float` | a finite `float` or `double` |
| `isFinite(s, n)` | `bool` | whether a `float` / `double` is neither NaN nor infinite |
| `floatBits(s, n)` | `int` | the IEEE 754 bits of a `float` / `double` |
| `asBool(s, n)` | `bool` | a `boolean` |
| `asString(s, n)` | `string` | a string, an enum constant's name, a `char` |
| `asBytes(s, n)` | `bytes` | a block's bytes (big-endian primitives) or a `byte[]` |
| `length(s, n)` | `int` | an array's elements, a string's runes, a block's bytes |
| `elementType(s, n)` | `string` | an array's element type: a primitive name, `object` or `array` |
| `ints(s, n)` | `list of int` | a `byte[]` `short[]` `int[]` `long[]` `char[]` `boolean[]` |
| `floats(s, n)` | `list of float` | a `float[]` / `double[]` without NaN or infinities |
| `floatArrayBits(s, n)` | `list of int` | the IEEE 754 bits of each `float[]` / `double[]` element |

## Dumping

| Function | Returns | Does |
|---|---|---|
| `dump(s)` | `string` | the stream as an indented tree, one value per line |
| `dumpWith(s, preview)` | `string` | the same, showing `preview` array elements and block bytes |

## Types

### `Options`

| Field | Meaning |
|---|---|
| `offset as int` | where the stream starts in the bytes; `locate` finds it behind a header |
| `maxNodes as int` | the most nodes the stream may produce; more is kind `"limit"` |
| `maxDepth as int` | the deepest nesting of objects and arrays; deeper is kind `"limit"` |

### `Stream`

The tables behind the accessors, one entry per node (lists indexed by node
number) or per class (indexed by class number). Prefer the accessors; the
layout is plain lists so a `Stream` is not rebuilt when passed to the deck.

| Field | Meaning |
|---|---|
| `data as bytes` | the bytes decoded |
| `offset as int` | where the stream starts in `data` |
| `kinds as list of int` | each node's kind, an index into the `typeOf` names |
| `classOf as list of int` | each node's class number, -1 for none |
| `ints as list of int` | a primitive value, a float's bits, an array length, a block's byte count |
| `floats as list of float` | a finite `float` / `double` value, else 0.0 |
| `texts as list of string` | a string, an enum constant, a char |
| `at as list of int` | a primitive array's first element in `data`, -1 otherwise |
| `segments as map of int to list of int` | a block's pieces in `data`, offset / length pairs |
| `children as list of list of int` | each node's children: fields, custom data, elements |
| `names as list of list of string` | each child's field name, `""` for custom data and elements |
| `owners as list of list of int` | each child's class number, -1 for array elements |
| `classNames as list of string` | each class's name, `$Proxy` for a proxy class |
| `classUids as list of int` | each class's serialVersionUID |
| `classFlags as list of int` | each class's `SC_*` flags |
| `classSupers as list of int` | each class's superclass, -1 for none |
| `classFieldNames as list of list of string` | each class's serializable fields, in stream order |
| `classFieldTypes as list of list of string` | each field's type code: `B C D F I J S Z`, `L` object, `[` array |
| `classFieldClasses as list of list of string` | each object field's declared type, `""` for primitives |
| `classInterfaces as list of list of string` | a proxy class's interfaces |
| `top as list of int` | the top-level nodes |
