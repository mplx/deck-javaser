<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @mplx/javaser

Java™ programs save objects with `ObjectOutputStream`: `.ser` files,
application project files, caches, session stores, RMI payloads. This deck
reads that format, the Java Object Serialization Stream Protocol (version 5,
every JDK™ since 1.2), without a JVM and without running any Java code.

The stream says which classes it holds, their serializable fields and the
values, and it records shared objects as back-references. The deck decodes
all of it into a `Stream` of numbered nodes. What a class writes in its own
`writeObject` / `writeExternal` method is kept as it was written: blocks of
primitive data and the objects between them. Their meaning is up to the
program that knows the class.

## Conventions

Snippets assume this import:

```jennifer
import "@mplx/javaser/" as javaser;

def s as javaser.Stream init javaser.decode(fs.readBytes("objects.ser"));
io.printf("%s", javaser.dump($s));
```

Nodes are plain ints. Node 0 is `null`, so a field that held `null` reads as
0. An object written once and referenced again is one node, reachable from
both places.

Errors: every failure is `Error{kind: "javaser"}` - a malformed or truncated
stream, an accessor given the wrong node - except a reached cap
(`Options.maxNodes`, `Options.maxDepth`), which is kind `"limit"`. A stream
whose writer failed midway (`TC_EXCEPTION`) is refused with the exception's
class and message.

- [Reading a stream](reading.md) walks through an unknown file.
- [Custom data](custom.md) covers `writeObject` and `Externalizable` classes.
- The [cheatsheet](cheatsheet.md) lists the whole API.

## Trademarks

Java™, JDK™ and OpenJDK™ are trademarks of Oracle Corporation and/or its
affiliates. Other product and company names may be trademarks of their
respective owners. They are used only to identify the products this deck works
with. This deck is an independent project, not affiliated with, sponsored or
endorsed by Oracle.
