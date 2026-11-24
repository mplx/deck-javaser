<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Custom data

Many classes do not leave their state to the default field mechanism. A
`Serializable` class with a `writeObject` method writes its fields and then
anything else it likes; an `Externalizable` class writes everything itself in
`writeExternal`, with no fields at all. The JDK™'s own collections do this:
`ArrayList` writes its size and then each element.

The stream keeps what was written in order: runs of primitive writes
(`writeInt`, `writeUTF`, `writeDouble`, ...) as block data, and every
`writeObject` as the object. `custom` returns them as nodes:

```text
[0]: Fixtures$Ext #1 {
  -- custom data of Fixtures$Ext
  [0]: block[4] 00000007
  [1]: "name" #3
  [2]: block[8] 4004000000000000
}
```

A block holds the bytes of `DataOutput`, big-endian; decode them with the
`binary` readers:

```jennifer
def parts as list of int init javaser.custom($s, $n);
def head as bytes init javaser.asBytes($s, $parts[0]);
def version as int init binary.readInt("be", $head, 0, 4);
def name as string init javaser.asString($s, $parts[1]);
def weight as float init binary.readFloat("be", javaser.asBytes($s, $parts[2]), 0, 8);
```

`writeUTF` inside a block is a two-byte length followed by the text.

Java™ splits long runs of primitive data into blocks of at most 1024 bytes,
and the boundaries carry no meaning (a `writeLong` can straddle one). The
deck joins adjacent blocks of the same class into one node, so a block is
exactly what the class wrote between two objects.

When several classes of an object's chain write custom data, `customOf`
returns one class's part:

```jennifer
def own as list of int init javaser.customOf($s, $n, "com.example.Sample");
```

The layout of custom data is the class's private business and can change
between versions of the program that wrote it. The first int is often a
version number; checking it before trusting the rest is a good habit.
