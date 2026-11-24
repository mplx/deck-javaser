<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Reading a stream

## Decode

A plain `.ser` file starts with the stream magic `AC ED 00 05`:

```jennifer
def s as javaser.Stream init javaser.decode(fs.readBytes("objects.ser"));
```

Some applications put a header of their own in front of it, such as the
program's name and version. `locate` finds the stream and `decodeWith`
starts there:

```jennifer
def b as bytes init fs.readBytes("project.ser");
def o as javaser.Options init javaser.defaults();
$o.offset = javaser.locate($b);
def s as javaser.Stream init javaser.decodeWith($b, $o);
```

The same options set the caps. Streams from an untrusted source should get
caps that fit what is expected; the defaults allow 2 million values.

## Look around

`dump` prints the whole graph, which is the fastest way into an unknown
format:

```text
[0]: java.util.HashMap #1 {
  loadFactor: float 0.75
  threshold: int 12
  -- custom data of java.util.HashMap
  [0]: block[8] 0000001000000001
  [1]: "one" #5
  [2]: java.lang.Integer #6 {
    value: int 1
  }
}
```

Each line is a label (a field name, or an index among custom data and array
elements) and a value. `#n` is the node number; `-> #n` marks an object
printed before.

## Navigate

`contents` gives the top-level values. From an object, `field` follows a
field and `custom` lists what the class wrote itself; from an object array,
`elements` lists the elements:

```jennifer
def hashMap as int init javaser.contents($s)[0];
io.printf("%s, load factor %f\n", javaser.className($s, $hashMap),
    javaser.asFloat($s, javaser.field($s, $hashMap, "loadFactor")));
for (def n in javaser.custom($s, $hashMap)) {
    io.printf("  %s\n", javaser.typeOf($s, $n));
}
```

`objectsOf` finds every object of a class wherever it sits, which is often
quicker than walking down to it:

```jennifer
for (def n in javaser.objectsOf($s, "com.example.Order")) {
    io.printf("%s\n", javaser.asString($s, javaser.field($s, $n, "name")));
}
```

## Read values

| Node | Read with |
|---|---|
| `byte` `short` `int` `long` | `asInt` |
| `char` | `asString`, or `asInt` for the code unit |
| `boolean` | `asBool` |
| `float` `double` | `asFloat`; `isFinite` / `floatBits` for NaN and infinities |
| string, enum constant | `asString` |
| primitive array | `ints`, `floats`, `asBytes` (`byte[]`) |
| object array | `elements` |
| block | `asBytes` |

Java™'s NaN and infinities have no Jennifer value, so `asFloat` refuses them;
`floatBits` returns their IEEE 754 bits instead. A Java string can hold a
surrogate without its pair, which no Jennifer string can: it reads as U+FFFD.
