# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# javaser - values: reading a decoded stream by node number. Spliced into
# javaser.j via include.

# Fail unless n is a node of s.
func checkNode(s as Stream, n as int) {
    if ($n < 0 or $n >= len($s.kinds)) {
        throw Error{
            kind: "javaser",
            message: io.sprintf("no node %d (the stream has %d)", $n, len($s.kinds))
        };
    }
}

# Fail with what a node is and what was wanted.
func wrongKind(s as Stream, n as int, wanted as string) {
    throw Error{
        kind: "javaser",
        message: io.sprintf("node %d is %s, not %s", $n, KIND_NAMES[$s.kinds[$n]], $wanted)
    };
}

/**
 * The stream's top-level values, in the order they were written: what each
 * `writeObject` call and each run of primitive writes (`writeInt`, ...)
 * produced. Primitive writes come as block nodes.
 *
 * @param s {Stream} the stream
 * @return {list of int} the top-level nodes
 */
export func contents(s as Stream) {
    return $s.top;
}

/**
 * The number of nodes, node 0 (`null`) included. Every number below it is a
 * valid node.
 *
 * @param s {Stream} the stream
 * @return {int} the node count
 */
export func nodeCount(s as Stream) {
    return len($s.kinds);
}

/**
 * What a node is: `"null"`, `"object"`, `"array"`, `"string"`, `"enum"`,
 * `"class"` (a `Class` object), `"classdesc"`, `"block"` (custom data
 * written with `writeInt` and the like), or a primitive field value:
 * `"boolean"`, `"byte"`, `"char"`, `"short"`, `"int"`, `"long"`,
 * `"float"`, `"double"`.
 *
 * @param s {Stream} the stream
 * @param n {int} the node
 * @return {string} its kind
 * @throws {Error} kind "javaser" when there is no such node
 */
export func typeOf(s as Stream, n as int) {
    checkNode($s, $n);
    return KIND_NAMES[$s.kinds[$n]];
}

/**
 * The Java class name of an object, array, enum constant, `Class` object or
 * class descriptor (`java.util.ArrayList`, `[I`, `[Ljava.lang.String;`);
 * `"$Proxy"` for a dynamic proxy. `""` for other nodes.
 *
 * @param s {Stream} the stream
 * @param n {int} the node
 * @return {string} the class name
 * @throws {Error} kind "javaser" when there is no such node
 */
export func className(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.classOf[$n] < 0) {
        return "";
    }
    return $s.classNames[$s.classOf[$n]];
}

/**
 * The serializable classes of a node's class, superclass first: the order
 * their data appears in. Empty for a node without a class.
 *
 * @param s {Stream} the stream
 * @param n {int} the node
 * @return {list of string} the class names
 * @throws {Error} kind "javaser" when there is no such node
 */
export func classChain(s as Stream, n as int) {
    checkNode($s, $n);
    def out as list of string init [];
    def c as int init $s.classOf[$n];
    while ($c >= 0 and len($out) <= len($s.classNames)) {
        $out[] = $s.classNames[$c];
        $c = $s.classSupers[$c];
    }
    return lists.reverse($out);
}

/**
 * The serialVersionUID of a node's class; 0 for a node without a class.
 *
 * @param s {Stream} the stream
 * @param n {int} the node
 * @return {int} the UID
 * @throws {Error} kind "javaser" when there is no such node
 */
export func serialVersionUid(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.classOf[$n] < 0) {
        return 0;
    }
    return $s.classUids[$s.classOf[$n]];
}

/**
 * The interface names of a dynamic proxy (`$Proxy`) node's class; empty for
 * other nodes.
 *
 * @param s {Stream} the stream
 * @param n {int} the node
 * @return {list of string} the interfaces
 * @throws {Error} kind "javaser" when there is no such node
 */
export func interfaces(s as Stream, n as int) {
    checkNode($s, $n);
    def c as int init $s.classOf[$n];
    while ($c >= 0) {
        if (len($s.classInterfaces[$c]) > 0) {
            return $s.classInterfaces[$c];
        }
        $c = $s.classSupers[$c];
    }
    return [];
}

/**
 * The serializable field names of an object, superclass fields first. A
 * field a subclass shadows appears twice; `field` reads the subclass's,
 * `fieldOf` either.
 *
 * @param s {Stream} the stream
 * @param n {int} the object
 * @return {list of string} the field names
 * @throws {Error} kind "javaser" when there is no such node
 */
export func fieldNames(s as Stream, n as int) {
    checkNode($s, $n);
    def out as list of string init [];
    for (def name in $s.names[$n]) {
        if ($name != "") {
            $out[] = $name;
        }
    }
    return $out;
}

/**
 * Whether an object has a serializable field of that name.
 *
 * @param s {Stream} the stream
 * @param n {int} the object
 * @param name {string} the field name
 * @return {bool} whether it has the field
 * @throws {Error} kind "javaser" when there is no such node
 */
export func has(s as Stream, n as int, name as string) {
    checkNode($s, $n);
    return $name != "" and lists.contains($s.names[$n], $name);
}

/**
 * A field's value. With a shadowed field, the most derived class's.
 *
 * @param s {Stream} the stream
 * @param n {int} the object
 * @param name {string} the field name
 * @return {int} the value's node
 * @throws {Error} kind "javaser" when there is no such node or field
 * @example
 *   def size as int init javaser.asInt($s, javaser.field($s, $list, "size"));
 */
export func field(s as Stream, n as int, name as string) {
    checkNode($s, $n);
    def names as list of string init $s.names[$n];
    def i as int init len($names) - 1;
    while ($i >= 0) {
        if ($names[$i] == $name and $name != "") {
            return $s.children[$n][$i];
        }
        $i = $i - 1;
    }
    throw Error{
        kind: "javaser",
        message: io.sprintf("node %d (%s) has no field %s", $n, className($s, $n), $name)
    };
}

/**
 * A field's value as one class of the object's chain declares it: for a
 * field a subclass shadows.
 *
 * @param s {Stream} the stream
 * @param n {int} the object
 * @param cls {string} the declaring class
 * @param name {string} the field name
 * @return {int} the value's node
 * @throws {Error} kind "javaser" when there is no such node or field
 */
export func fieldOf(s as Stream, n as int, cls as string, name as string) {
    checkNode($s, $n);
    for (def i in 0..len($s.names[$n])) {
        def owner as int init $s.owners[$n][$i];
        if ($s.names[$n][$i] == $name and $owner >= 0 and $s.classNames[$owner] == $cls) {
            return $s.children[$n][$i];
        }
    }
    throw Error{
        kind: "javaser",
        message: io.sprintf("node %d has no field %s.%s", $n, $cls, $name)
    };
}

/**
 * An object's custom data, in order: what its classes' `writeObject` or
 * `writeExternal` wrote beyond the default fields. Primitive writes arrive
 * as block nodes (read with `asBytes`), objects as their nodes. Adjacent
 * blocks of one class are joined.
 *
 * @param s {Stream} the stream
 * @param n {int} the object
 * @return {list of int} the nodes
 * @throws {Error} kind "javaser" when there is no such node
 */
export func custom(s as Stream, n as int) {
    checkNode($s, $n);
    def out as list of int init [];
    for (def i in 0..len($s.names[$n])) {
        if ($s.names[$n][$i] == "" and $s.owners[$n][$i] >= 0) {
            $out[] = $s.children[$n][$i];
        }
    }
    return $out;
}

/**
 * The custom data one class of an object's chain wrote.
 *
 * @param s {Stream} the stream
 * @param n {int} the object
 * @param cls {string} the class
 * @return {list of int} the nodes, empty when that class wrote none
 * @throws {Error} kind "javaser" when there is no such node
 */
export func customOf(s as Stream, n as int, cls as string) {
    checkNode($s, $n);
    def out as list of int init [];
    for (def i in 0..len($s.names[$n])) {
        def owner as int init $s.owners[$n][$i];
        if ($s.names[$n][$i] == "" and $owner >= 0 and $s.classNames[$owner] == $cls) {
            $out[] = $s.children[$n][$i];
        }
    }
    return $out;
}

/**
 * The elements of an object array (`[Ljava.lang.String;`, `[[I`, ...).
 * Primitive arrays are read with `ints`, `floats` or `asBytes`.
 *
 * @param s {Stream} the stream
 * @param n {int} the array
 * @return {list of int} the element nodes
 * @throws {Error} kind "javaser" when the node is not an object array
 */
export func elements(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.kinds[$n] != K_ARRAY or $s.at[$n] >= 0) {
        wrongKind($s, $n, "an object array");
    }
    return $s.children[$n];
}

/**
 * An array's element type: `"boolean"`, `"byte"`, `"char"`, `"short"`,
 * `"int"`, `"long"`, `"float"`, `"double"`, `"object"` or `"array"`.
 *
 * @param s {Stream} the stream
 * @param n {int} the array
 * @return {string} the element type
 * @throws {Error} kind "javaser" when the node is not an array
 */
export func elementType(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.kinds[$n] != K_ARRAY) {
        wrongKind($s, $n, "an array");
    }
    match ($s.classNames[$s.classOf[$n]][1..2]) {
        when "Z" { return "boolean"; }
        when "B" { return "byte"; }
        when "C" { return "char"; }
        when "S" { return "short"; }
        when "I" { return "int"; }
        when "J" { return "long"; }
        when "F" { return "float"; }
        when "D" { return "double"; }
        when "[" { return "array"; }
    }
    return "object";
}

/**
 * A length: an array's element count, a string's rune count, a block's
 * byte count.
 *
 * @param s {Stream} the stream
 * @param n {int} an array, string or block
 * @return {int} the length
 * @throws {Error} kind "javaser" for other nodes
 */
export func length(s as Stream, n as int) {
    checkNode($s, $n);
    def k as int init $s.kinds[$n];
    if ($k == K_ARRAY or $k == K_BLOCK) {
        return $s.ints[$n];
    }
    if ($k == K_STRING) {
        return len($s.texts[$n]);
    }
    wrongKind($s, $n, "an array, string or block");
}

/**
 * An integer field value: `byte`, `short`, `int`, `long`, or a `char` as
 * its UTF-16 code unit.
 *
 * @param s {Stream} the stream
 * @param n {int} the value
 * @return {int} the integer
 * @throws {Error} kind "javaser" for other nodes
 */
export func asInt(s as Stream, n as int) {
    checkNode($s, $n);
    def k as int init $s.kinds[$n];
    if ($k == K_BYTE or $k == K_SHORT or $k == K_INT or $k == K_LONG or $k == K_CHAR) {
        return $s.ints[$n];
    }
    wrongKind($s, $n, "an integer");
}

/**
 * A `float` or `double` field value. NaN and the infinities have no
 * Jennifer value: test with `isFinite`, read them with `floatBits`.
 *
 * @param s {Stream} the stream
 * @param n {int} the value
 * @return {float} the number
 * @throws {Error} kind "javaser" for other nodes and for NaN or an infinity
 */
export func asFloat(s as Stream, n as int) {
    if (not isFinite($s, $n)) {
        throw Error{
            kind: "javaser",
            message: io.sprintf("node %d is NaN or infinite; read floatBits", $n)
        };
    }
    return $s.floats[$n];
}

/**
 * Whether a `float` or `double` field value is finite (not NaN, not an
 * infinity).
 *
 * @param s {Stream} the stream
 * @param n {int} the value
 * @return {bool} whether it is finite
 * @throws {Error} kind "javaser" for other nodes
 */
export func isFinite(s as Stream, n as int) {
    def bits as int init floatBits($s, $n);
    if ($s.kinds[$n] == K_FLOAT) {
        return ($bits >> 23) & 0xFF != 0xFF;
    }
    return ($bits >> 52) & 0x7FF != 0x7FF;
}

/**
 * The IEEE 754 bits of a `float` (32, unsigned) or `double` (64, as a
 * signed int) field value; works for NaN and the infinities.
 *
 * @param s {Stream} the stream
 * @param n {int} the value
 * @return {int} the bits
 * @throws {Error} kind "javaser" for other nodes
 */
export func floatBits(s as Stream, n as int) {
    checkNode($s, $n);
    def k as int init $s.kinds[$n];
    if ($k != K_FLOAT and $k != K_DOUBLE) {
        wrongKind($s, $n, "a float or double");
    }
    return $s.ints[$n];
}

/**
 * A `boolean` field value.
 *
 * @param s {Stream} the stream
 * @param n {int} the value
 * @return {bool} the value
 * @throws {Error} kind "javaser" for other nodes
 */
export func asBool(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.kinds[$n] != K_BOOLEAN) {
        wrongKind($s, $n, "a boolean");
    }
    return $s.ints[$n] != 0;
}

/**
 * Text: a string, an enum constant's name, a `char`. Java text is UTF-16;
 * a surrogate without its pair becomes U+FFFD.
 *
 * @param s {Stream} the stream
 * @param n {int} the value
 * @return {string} the text
 * @throws {Error} kind "javaser" for other nodes
 */
export func asString(s as Stream, n as int) {
    checkNode($s, $n);
    def k as int init $s.kinds[$n];
    if ($k == K_STRING or $k == K_ENUM or $k == K_CHAR) {
        return $s.texts[$n];
    }
    wrongKind($s, $n, "a string, enum or char");
}

/**
 * The bytes of a block (custom primitive data) or a `byte[]`. Decode a
 * block with the `binary` readers, big-endian: Java's `DataOutput` order.
 *
 * @param s {Stream} the stream
 * @param n {int} a block or byte array
 * @return {bytes} the bytes
 * @throws {Error} kind "javaser" for other nodes
 * @example
 *   def b as bytes init javaser.asBytes($s, $block);
 *   def version as int init binary.readInt("be", $b, 0, 4);
 */
export func asBytes(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.kinds[$n] == K_BLOCK) {
        def seg as list of int init $s.segments[$n];
        if (len($seg) == 2) {
            return $s.data[$seg[0]..$seg[0] + $seg[1]];
        }
        def parts as list of bytes init [];
        for (def i in 0..len($seg) // 2) {
            $parts[] = $s.data[$seg[2 * $i]..$seg[2 * $i] + $seg[2 * $i + 1]];
        }
        return binary.join($parts);
    }
    if ($s.kinds[$n] == K_ARRAY and elementType($s, $n) == "byte") {
        return $s.data[$s.at[$n]..$s.at[$n] + $s.ints[$n]];
    }
    wrongKind($s, $n, "a block or byte array");
}

/**
 * The elements of an integer array: `byte[]`, `short[]`, `int[]`,
 * `long[]`, `char[]` (code units) or `boolean[]` (0 / 1).
 *
 * @param s {Stream} the stream
 * @param n {int} the array
 * @return {list of int} the elements
 * @throws {Error} kind "javaser" for other nodes
 */
export func ints(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.kinds[$n] != K_ARRAY) {
        wrongKind($s, $n, "an integer array");
    }
    def t as string init elementType($s, $n);
    def count as int init $s.ints[$n];
    def at as int init $s.at[$n];
    if ($t == "int" or $t == "long" or $t == "short" or $t == "byte") {
        if ($count == 0) {
            return [];
        }
        return binary.readInts(
            "be",
            $s.data,
            $at,
            $count,
            elementSize($s.classNames[$s.classOf[$n]][1..2]));
    }
    if ($t == "char" or $t == "boolean") {
        def size as int init 2;
        if ($t == "boolean") {
            $size = 1;
        }
        def out as list of int init [];
        for (def i in 0..$count) {
            def v as int init binary.readUint("be", $s.data, $at + $i * $size, $size);
            if ($t == "boolean" and $v != 0) {
                $v = 1;
            }
            $out[] = $v;
        }
        return $out;
    }
    wrongKind($s, $n, "an integer array");
}

/**
 * The elements of a `float[]` or `double[]`.
 *
 * @param s {Stream} the stream
 * @param n {int} the array
 * @return {list of float} the elements
 * @throws {Error} kind "javaser" for other nodes, and when an element is NaN or infinite (read `floatArrayBits`)
 */
export func floats(s as Stream, n as int) {
    def bits as list of int init floatArrayBits($s, $n);
    def size as int init 8;
    def mask as int init 0x7FF;
    def shift as int init 52;
    if (elementType($s, $n) == "float") {
        $size = 4;
        $mask = 0xFF;
        $shift = 23;
    }
    for (def i in 0..len($bits)) {
        if (($bits[$i] >> $shift) & $mask == $mask) {
            throw Error{
                kind: "javaser",
                message: io.sprintf(
                    "node %d element %d is NaN or infinite; read floatArrayBits",
                    $n,
                    $i)
            };
        }
    }
    if (len($bits) == 0) {
        return [];
    }
    return binary.readFloats("be", $s.data, $s.at[$n], len($bits), $size);
}

/**
 * The IEEE 754 bits of each element of a `float[]` (32, unsigned) or
 * `double[]` (64, signed); works for NaN and the infinities.
 *
 * @param s {Stream} the stream
 * @param n {int} the array
 * @return {list of int} the bits
 * @throws {Error} kind "javaser" for other nodes
 */
export func floatArrayBits(s as Stream, n as int) {
    checkNode($s, $n);
    if ($s.kinds[$n] != K_ARRAY) {
        wrongKind($s, $n, "a float or double array");
    }
    def t as string init elementType($s, $n);
    if ($t != "float" and $t != "double") {
        wrongKind($s, $n, "a float or double array");
    }
    def size as int init 8;
    if ($t == "float") {
        $size = 4;
    }
    def out as list of int init [];
    for (def i in 0..$s.ints[$n]) {
        if ($size == 4) {
            $out[] = binary.readUint("be", $s.data, $s.at[$n] + 4 * $i, 4);
        } else {
            $out[] = binary.readInt("be", $s.data, $s.at[$n] + 8 * $i, 8);
        }
    }
    return $out;
}

/**
 * Every object of a class, in stream order, wherever it sits in the graph
 * (`"com.example.Order"`). Subclasses do not match.
 *
 * @param s {Stream} the stream
 * @param cls {string} the class name
 * @return {list of int} the object nodes
 */
export func objectsOf(s as Stream, cls as string) {
    def out as list of int init [];
    for (def n in 0..len($s.kinds)) {
        if ($s.kinds[$n] == K_OBJECT and $s.classNames[$s.classOf[$n]] == $cls) {
            $out[] = $n;
        }
    }
    return $out;
}
