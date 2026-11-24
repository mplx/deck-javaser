# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# javaser - stream: decoding a Java Object Serialization stream into the
# node tables of a `Stream`. Spliced into javaser.j via include.
#
# The parser keeps its own stack of frames instead of recursing per nested
# object, so a long object chain (a linked list written by Java) does not hit
# the interpreter's call-depth limit. Only class descriptors recurse: their
# superclass chain and their annotations.

# type codes (java.io.ObjectStreamConstants)
def const TC_NULL as int init 0x70;
def const TC_REFERENCE as int init 0x71;
def const TC_CLASSDESC as int init 0x72;
def const TC_OBJECT as int init 0x73;
def const TC_STRING as int init 0x74;
def const TC_ARRAY as int init 0x75;
def const TC_CLASS as int init 0x76;
def const TC_BLOCKDATA as int init 0x77;
def const TC_ENDBLOCKDATA as int init 0x78;
def const TC_RESET as int init 0x79;
def const TC_BLOCKDATALONG as int init 0x7A;
def const TC_EXCEPTION as int init 0x7B;
def const TC_LONGSTRING as int init 0x7C;
def const TC_PROXYCLASSDESC as int init 0x7D;
def const TC_ENUM as int init 0x7E;

def const STREAM_MAGIC as int init 0xACED;
def const STREAM_VERSION as int init 5;
def const BASE_HANDLE as int init 0x7E0000;

/** Class flag: the class has a `writeObject` method (custom data follows its fields). */
export def const SC_WRITE_METHOD as int init 0x01;
/** Class flag: the class is `Serializable`. */
export def const SC_SERIALIZABLE as int init 0x02;
/** Class flag: the class is `Externalizable` (its data is custom only). */
export def const SC_EXTERNALIZABLE as int init 0x04;
/** Class flag: externalizable data is written as block data (protocol 2). */
export def const SC_BLOCK_DATA as int init 0x08;
/** Class flag: the class is an enum. */
export def const SC_ENUM as int init 0x10;

/** Default cap on the nodes one stream may produce (`Options.maxNodes`). */
export def const DEFAULT_MAX_NODES as int init 2000000;
/** Default cap on nested objects and arrays (`Options.maxDepth`). */
export def const DEFAULT_MAX_DEPTH as int init 100000;

# node kinds, indexes into KIND_NAMES
def const K_NULL as int init 0;
def const K_OBJECT as int init 1;
def const K_ARRAY as int init 2;
def const K_STRING as int init 3;
def const K_ENUM as int init 4;
def const K_CLASS as int init 5;
def const K_CLASSDESC as int init 6;
def const K_BLOCK as int init 7;
def const K_BOOLEAN as int init 8;
def const K_BYTE as int init 9;
def const K_CHAR as int init 10;
def const K_SHORT as int init 11;
def const K_INT as int init 12;
def const K_LONG as int init 13;
def const K_FLOAT as int init 14;
def const K_DOUBLE as int init 15;
def const KIND_NAMES as list of string init [
    "null",
    "object",
    "array",
    "string",
    "enum",
    "class",
    "classdesc",
    "block",
    "boolean",
    "byte",
    "char",
    "short",
    "int",
    "long",
    "float",
    "double",
];

# parser frame modes
def const M_TOP as int init 0;
def const M_BLOCK as int init 1;
def const M_FIELDS as int init 2;
def const M_ELEMENTS as int init 3;
def const M_ABORT as int init 4;

# attach targets that are not nodes
def const TOP as int init -1;
def const DISCARD as int init -2;

/**
 * How `decodeWith` reads a stream. Start from `defaults()`.
 *
 * @field offset {int} where the stream starts in the bytes (its `AC ED 00 05` magic); `locate` finds it behind a header
 * @field maxNodes {int} the most nodes the stream may produce; more is kind "limit"
 * @field maxDepth {int} the deepest nesting of objects and arrays; deeper is kind "limit"
 */
export def struct Options {
    offset as int,
    maxNodes as int,
    maxDepth as int
};

/**
 * A decoded stream: every value as a numbered node, and every class
 * descriptor as a numbered class. Read it with the accessors (`contents`,
 * `typeOf`, `field`, ...), which take a node number; the fields are the
 * tables behind them. Node 0 is `null`. A value written once and referenced
 * again (a Java back-reference) is one node, reachable from both places.
 *
 * @field data {bytes} the bytes decoded
 * @field offset {int} where the stream starts in `data`
 * @field kinds {list of int} each node's kind, an index into the `typeOf` names
 * @field classOf {list of int} each node's class number, -1 for none
 * @field ints {list of int} each node's integer: a primitive value, a float's IEEE bits, an array length, a block's byte count
 * @field floats {list of float} each node's float value, 0.0 unless a finite float or double
 * @field texts {list of string} each node's text: a string, an enum constant, a char
 * @field at {list of int} each primitive array's first element in `data`, -1 for other nodes
 * @field segments {map of int to list of int} each block node's pieces in `data`, as offset, length pairs
 * @field children {list of list of int} each node's child nodes: fields, custom data, array elements
 * @field names {list of list of string} each child's field name, `""` for custom data and array elements
 * @field owners {list of list of int} each child's class number: the class whose field or custom data it is, -1 for array elements
 * @field classNames {list of string} each class's name (`java.util.ArrayList`, `[I`, `$Proxy` for a proxy class)
 * @field classUids {list of int} each class's serialVersionUID
 * @field classFlags {list of int} each class's flags (`SC_*`)
 * @field classSupers {list of int} each class's superclass number, -1 for none
 * @field classFieldNames {list of list of string} each class's serializable field names, in stream order
 * @field classFieldTypes {list of list of string} each field's type code: `B C D F I J S Z` primitives, `L` object, `[` array
 * @field classFieldClasses {list of list of string} each object field's declared type (`Ljava/lang/String;`), `""` for primitives
 * @field classInterfaces {list of list of string} a proxy class's interface names, empty for other classes
 * @field top {list of int} the stream's top-level nodes, in order
 */
export def struct Stream {
    data as bytes,
    offset as int,
    kinds as list of int,
    classOf as list of int,
    ints as list of int,
    floats as list of float,
    texts as list of string,
    at as list of int,
    segments as map of int to list of int,
    children as list of list of int,
    names as list of list of string,
    owners as list of list of int,
    classNames as list of string,
    classUids as list of int,
    classFlags as list of int,
    classSupers as list of int,
    classFieldNames as list of list of string,
    classFieldTypes as list of list of string,
    classFieldClasses as list of list of string,
    classInterfaces as list of list of string,
    top as list of int
};

# One open container on the parser's stack.
def struct Frame {
    mode as int,
    node as int,
    owner as int,
    chain as list of int,
    ci as int,
    fi as int,
    remaining as int
};

# The parser: the stream under construction plus the cursor. Functions take
# it and return it (`$p = f($p)`), which moves it rather than copying.
def struct Parser {
    s as Stream,
    pos as int,
    end as int,
    handles as list of int,
    frames as list of Frame,
    depth as int,
    opts as Options,
    rint as int,
    rstr as string
};

/**
 * The default options: the stream at offset 0, `DEFAULT_MAX_NODES` and
 * `DEFAULT_MAX_DEPTH`.
 *
 * @return {Options} the defaults
 */
export func defaults() {
    return Options{offset: 0, maxNodes: DEFAULT_MAX_NODES, maxDepth: DEFAULT_MAX_DEPTH};
}

/**
 * Where a serialization stream starts in some bytes: the first `AC ED 00 05`.
 * Files that wrap a stream in a header of their own (an application's
 * name and version in front of the magic) need it as `Options.offset`.
 *
 * @param data {bytes} the bytes to search
 * @return {int} the offset of the magic, -1 when there is none
 */
export func locate(data as bytes) {
    return binary.indexOf($data, encoding.fromText("hex", "aced0005"));
}

/**
 * Decode a serialization stream that starts at the first byte.
 *
 * @param data {bytes} the stream, as `ObjectOutputStream` wrote it
 * @return {Stream} the decoded stream
 * @throws {Error} kind "javaser" for a malformed or truncated stream, or one the writer aborted (`TC_EXCEPTION`); kind "limit" past `DEFAULT_MAX_NODES` or `DEFAULT_MAX_DEPTH`
 * @example
 *   def s as javaser.Stream init javaser.decode(fs.readBytes("objects.ser"));
 */
export func decode(data as bytes) {
    return decodeWith($data, defaults());
}

/**
 * Decode a serialization stream with options: an offset into the bytes and
 * the caps on its size.
 *
 * @param data {bytes} the bytes holding the stream
 * @param opts {Options} where it starts and how much it may produce
 * @return {Stream} the decoded stream
 * @throws {Error} kind "javaser" for a malformed or truncated stream, one the writer aborted, or invalid options; kind "limit" when a cap is reached
 * @example
 *   def b as bytes init fs.readBytes("project.ser");
 *   def o as javaser.Options init javaser.defaults();
 *   $o.offset = javaser.locate($b);
 *   def s as javaser.Stream init javaser.decodeWith($b, $o);
 */
export func decodeWith(data as bytes, opts as Options) {
    if ($opts.offset < 0 or $opts.offset > len($data)) {
        throw Error{
            kind: "javaser",
            message: io.sprintf("offset %d is outside the %d bytes", $opts.offset, len($data))
        };
    }
    if ($opts.maxNodes < 1 or $opts.maxDepth < 1) {
        throw Error{kind: "javaser", message: "maxNodes and maxDepth must be positive"};
    }
    def p as Parser init Parser{
        s: Stream{
            data: $data,
            offset: $opts.offset,
            kinds: [K_NULL],
            classOf: [-1],
            ints: [0],
            floats: [0.0],
            texts: [""],
            at: [-1],
            segments: {},
            children: [[]],
            names: [[]],
            owners: [[]],
            classNames: [],
            classUids: [],
            classFlags: [],
            classSupers: [],
            classFieldNames: [],
            classFieldTypes: [],
            classFieldClasses: [],
            classInterfaces: [],
            top: []
        },
        pos: $opts.offset,
        end: len($data),
        handles: [],
        frames: [],
        depth: 0,
        opts: $opts,
        rint: 0,
        rstr: ""
    };
    need($p, 4);
    if (binary.readUint("be", $data, $p.pos, 2) != STREAM_MAGIC) {
        fail($p, "not a Java serialization stream: no AC ED magic");
    }
    def version as int init binary.readUint("be", $data, $p.pos + 2, 2);
    if ($version != STREAM_VERSION) {
        fail($p, io.sprintf("stream version %d; only version 5 exists", $version));
    }
    $p.pos = $p.pos + 4;
    $p = push($p, frame(M_TOP, TOP, -1));
    $p = run($p, 0);
    return $p.s;
}

# Throw a javaser error naming the byte where decoding stopped.
func fail(p as Parser, message as string) {
    throw Error{kind: "javaser", message: io.sprintf("%s (at byte %d)", $message, $p.pos)};
}

# Fail unless n more bytes are there.
func need(p as Parser, n as int) {
    if ($n < 0 or $p.pos + $n > $p.end) {
        fail($p, io.sprintf("truncated: %d more bytes needed, %d left", $n, $p.end - $p.pos));
    }
}

# A frame with no chain and no count.
func frame(mode as int, node as int, owner as int) {
    return Frame{
        mode: $mode,
        node: $node,
        owner: $owner,
        chain: [],
        ci: 0,
        fi: 0,
        remaining: 0
    };
}

# Push a frame. Slots above `depth` are reused: popping is `depth - 1`.
func push(p as Parser, f as Frame) {
    if ($p.depth >= $p.opts.maxDepth) {
        throw Error{
            kind: "limit",
            message: io.sprintf(
                "javaser: values nest deeper than %d (at byte %d)",
                $p.opts.maxDepth,
                $p.pos)
        };
    }
    if ($p.depth < len($p.frames)) {
        $p.frames[$p.depth] = $f;
    } else {
        $p.frames[] = $f;
    }
    $p.depth = $p.depth + 1;
    return $p;
}

# Step until the stack is back to `floor` frames.
func run(p as Parser, floor as int) {
    while ($p.depth > $floor) {
        $p = step($p);
    }
    return $p;
}

# Read the next thing the top frame expects, or pop it when it is complete.
func step(p as Parser) {
    def t as int init $p.depth - 1;
    def mode as int init $p.frames[$t].mode;
    def node as int init $p.frames[$t].node;
    if ($mode == M_FIELDS) {
        $p = fieldStep($p, $t);
        return $p;
    }
    if ($mode == M_TOP) {
        if ($p.pos >= $p.end) {
            $p.depth = $t;
            return $p;
        }
        $p = content($p, $node, "", -1, true);
        return $p;
    }
    if ($mode == M_BLOCK) {
        need($p, 1);
        if ($p.s.data[$p.pos] == TC_ENDBLOCKDATA) {
            $p.pos = $p.pos + 1;
            $p.depth = $t;
            return $p;
        }
        def slotOwner as int init $p.frames[$t].owner;
        $p = content($p, $node, "", $slotOwner, true);
        return $p;
    }
    if ($p.frames[$t].remaining == 0) {
        $p.depth = $t;
        if ($mode == M_ABORT) {
            aborted($p, $node);
        }
        return $p;
    }
    $p.frames[$t].remaining = $p.frames[$t].remaining - 1;
    $p = content($p, $node, "", -1, false);
    return $p;
}

# One step through an object's classes: the next field, the class's custom
# data, or the end of the object.
func fieldStep(p as Parser, t as int) {
    def node as int init $p.frames[$t].node;
    def ci as int init $p.frames[$t].ci;
    if ($ci >= len($p.frames[$t].chain)) {
        $p.depth = $t;
        return $p;
    }
    def c as int init $p.frames[$t].chain[$ci];
    def fi as int init $p.frames[$t].fi;
    def flags as int init $p.s.classFlags[$c];
    def serializable as bool init $flags & SC_SERIALIZABLE != 0;
    if ($serializable and $fi < len($p.s.classFieldNames[$c])) {
        $p.frames[$t].fi = $fi + 1;
        def type as string init $p.s.classFieldTypes[$c][$fi];
        def name as string init $p.s.classFieldNames[$c][$fi];
        if ($type == "L" or $type == "[") {
            $p = content($p, $node, $name, $c, false);
            return $p;
        }
        $p = primitive($p, $type);
        def child as int init $p.rint;
        $p = attach($p, $node, $name, $c, $child);
        return $p;
    }
    $p.frames[$t].ci = $ci + 1;
    $p.frames[$t].fi = 0;
    if ($serializable and $flags & SC_WRITE_METHOD != 0) {
        $p = push($p, frame(M_BLOCK, $node, $c));
        return $p;
    }
    return $p;
}

# A new node of a kind; its number is left in rint.
func newNode(p as Parser, kind as int, cls as int) {
    if (len($p.s.kinds) >= $p.opts.maxNodes) {
        throw Error{
            kind: "limit",
            message: io.sprintf(
                "javaser: more than %d values (at byte %d)",
                $p.opts.maxNodes,
                $p.pos)
        };
    }
    $p.s.kinds[] = $kind;
    $p.s.classOf[] = $cls;
    $p.s.ints[] = 0;
    $p.s.floats[] = 0.0;
    $p.s.texts[] = "";
    $p.s.at[] = -1;
    $p.s.children[] = [];
    $p.s.names[] = [];
    $p.s.owners[] = [];
    $p.rint = len($p.s.kinds) - 1;
    return $p;
}

# Hang a child under a node, at top level, or nowhere (class annotations).
func attach(p as Parser, node as int, name as string, owner as int, child as int) {
    if ($node == DISCARD) {
        return $p;
    }
    if ($node == TOP) {
        $p.s.top[] = $child;
        return $p;
    }
    $p.s.children[$node][] = $child;
    $p.s.names[$node][] = $name;
    $p.s.owners[$node][] = $owner;
    return $p;
}

# Read one content element into node / name / owner. Block data, resets and
# the end marker are only allowed where custom data may stand (`inBlock`).
func content(p as Parser, node as int, name as string, owner as int, inBlock as bool) {
    need($p, 1);
    def tc as int init $p.s.data[$p.pos];
    $p.pos = $p.pos + 1;
    match ($tc) {
        when TC_NULL {
            $p = attach($p, $node, $name, $owner, 0);
            return $p;
        }
        when TC_REFERENCE {
            $p = reference($p);
            def child as int init $p.rint;
            $p = attach($p, $node, $name, $owner, $child);
            return $p;
        }
        when TC_STRING, TC_LONGSTRING {
            $p = newString($p, $tc == TC_LONGSTRING);
            def child as int init $p.rint;
            $p = attach($p, $node, $name, $owner, $child);
            return $p;
        }
        when TC_CLASSDESC, TC_PROXYCLASSDESC {
            $p.pos = $p.pos - 1;
            $p = classDesc($p);
            def descClass as int init $p.rint;
            $p = newNode($p, K_CLASSDESC, $descClass);
            def child as int init $p.rint;
            $p = attach($p, $node, $name, $owner, $child);
            return $p;
        }
        when TC_CLASS {
            $p = classDesc($p);
            def objClass as int init $p.rint;
            $p = newNode($p, K_CLASS, $objClass);
            $p.handles[] = $p.rint;
            def child as int init $p.rint;
            $p = attach($p, $node, $name, $owner, $child);
            return $p;
        }
        when TC_ENUM {
            $p = enumValue($p, $node, $name, $owner);
            return $p;
        }
        when TC_OBJECT {
            $p = object($p, $node, $name, $owner);
            return $p;
        }
        when TC_ARRAY {
            $p = array($p, $node, $name, $owner);
            return $p;
        }
        when TC_BLOCKDATA, TC_BLOCKDATALONG {
            if (not $inBlock) {
                fail($p, "block data where a field value or array element belongs");
            }
            $p = block($p, $node, $owner, $tc == TC_BLOCKDATALONG);
            return $p;
        }
        when TC_RESET {
            if (not $inBlock) {
                fail($p, "a reset where a field value or array element belongs");
            }
            $p.handles = [];
            return $p;
        }
        when TC_EXCEPTION {
            $p.handles = [];
            $p = newNode($p, K_NULL, -1);
            def f as Frame init frame(M_ABORT, $p.rint, -1);
            $f.remaining = 1;
            $p = push($p, $f);
            return $p;
        }
        when TC_ENDBLOCKDATA { fail($p, "an end of block data outside custom data"); }
    }
    $p.pos = $p.pos - 1;
    fail($p, io.sprintf("unknown type code 0x%d|base=16", $tc));
}

# TC_REFERENCE's handle, resolved to a node (rint). A handle naming a class
# descriptor yields a new classdesc node for it.
func reference(p as Parser) {
    need($p, 4);
    def h as int init binary.readInt("be", $p.s.data, $p.pos, 4) - BASE_HANDLE;
    if ($h < 0 or $h >= len($p.handles)) {
        fail($p, io.sprintf("reference to unknown handle 0x%d|base=16", $h + BASE_HANDLE));
    }
    $p.pos = $p.pos + 4;
    def target as int init $p.handles[$h];
    if ($target >= 0) {
        $p.rint = $target;
        return $p;
    }
    $p = newNode($p, K_CLASSDESC, -$target - 1);
    return $p;
}

# A string's length and text (modified UTF-8) into rstr.
func utf(p as Parser, long as bool) {
    def n as int init 0;
    if ($long) {
        need($p, 8);
        $n = binary.readInt("be", $p.s.data, $p.pos, 8);
        $p.pos = $p.pos + 8;
    } else {
        need($p, 2);
        $n = binary.readUint("be", $p.s.data, $p.pos, 2);
        $p.pos = $p.pos + 2;
    }
    need($p, $n);
    def text as string init mutf8($p.s.data[$p.pos..$p.pos + $n]);
    if ($text == "￿" and $n != 3) {
        fail($p, "malformed modified UTF-8 in a string");
    }
    $p.rstr = $text;
    $p.pos = $p.pos + $n;
    return $p;
}

# A string node from TC_STRING / TC_LONGSTRING (tc already read).
func newString(p as Parser, long as bool) {
    $p = utf($p, $long);
    $p = newNode($p, K_STRING, -1);
    $p.s.texts[$p.rint] = $p.rstr;
    $p.handles[] = $p.rint;
    return $p;
}

# A string in a place that holds one (a field's type, an enum constant):
# new, a reference to one, or null. Its text goes to rstr.
func stringValue(p as Parser) {
    need($p, 1);
    def tc as int init $p.s.data[$p.pos];
    $p.pos = $p.pos + 1;
    if ($tc == TC_STRING or $tc == TC_LONGSTRING) {
        $p = newString($p, $tc == TC_LONGSTRING);
        return $p;
    }
    if ($tc == TC_NULL) {
        $p.rstr = "";
        return $p;
    }
    if ($tc != TC_REFERENCE) {
        $p.pos = $p.pos - 1;
        fail($p, "expected a string");
    }
    $p = reference($p);
    if ($p.s.kinds[$p.rint] != K_STRING) {
        fail($p, "a reference that should name a string does not");
    }
    $p.rstr = $p.s.texts[$p.rint];
    return $p;
}

# A class descriptor: new, proxy, a reference or null. Its class number goes
# to rint (-1 for null).
func classDesc(p as Parser) {
    need($p, 1);
    def tc as int init $p.s.data[$p.pos];
    $p.pos = $p.pos + 1;
    if ($tc == TC_NULL) {
        $p.rint = -1;
        return $p;
    }
    if ($tc == TC_REFERENCE) {
        need($p, 4);
        def h as int init binary.readInt("be", $p.s.data, $p.pos, 4) - BASE_HANDLE;
        if ($h < 0 or $h >= len($p.handles) or $p.handles[$h] >= 0) {
            fail($p, "a class descriptor reference that names no class");
        }
        $p.pos = $p.pos + 4;
        $p.rint = -$p.handles[$h] - 1;
        return $p;
    }
    if ($tc == TC_PROXYCLASSDESC) {
        $p = proxyDesc($p);
        return $p;
    }
    if ($tc != TC_CLASSDESC) {
        $p.pos = $p.pos - 1;
        fail($p, io.sprintf("expected a class descriptor, got type code 0x%d|base=16", $tc));
    }
    $p = utf($p, false);
    def name as string init $p.rstr;
    need($p, 11);
    def uid as int init binary.readInt("be", $p.s.data, $p.pos, 8);
    def flags as int init $p.s.data[$p.pos + 8];
    def count as int init binary.readUint("be", $p.s.data, $p.pos + 9, 2);
    $p.pos = $p.pos + 11;
    def c as int init len($p.s.classNames);
    $p = addClass($p, $name, $uid, $flags);
    for (def i in 0..$count) {
        need($p, 1);
        def type as string init convert.fromCodepoint($p.s.data[$p.pos]);
        $p.pos = $p.pos + 1;
        if (not strings.contains("BCDFIJSZL[", $type)) {
            $p.pos = $p.pos - 1;
            fail($p, "unknown field type code " + $type);
        }
        $p = utf($p, false);
        $p.s.classFieldTypes[$c][] = $type;
        $p.s.classFieldNames[$c][] = $p.rstr;
        def declared as string init "";
        if ($type == "L" or $type == "[") {
            $p = stringValue($p);
            $declared = $p.rstr;
        }
        $p.s.classFieldClasses[$c][] = $declared;
    }
    $p = annotation($p);
    $p = classDesc($p);
    $p.s.classSupers[$c] = $p.rint;
    $p.rint = $c;
    return $p;
}

# A proxy class descriptor (tc already read): its interfaces, annotation and
# superclass (java.lang.reflect.Proxy).
func proxyDesc(p as Parser) {
    def c as int init len($p.s.classNames);
    $p = addClass($p, "$Proxy", 0, SC_SERIALIZABLE);
    need($p, 4);
    def n as int init binary.readInt("be", $p.s.data, $p.pos, 4);
    $p.pos = $p.pos + 4;
    if ($n < 0 or $n > 65535) {
        fail($p, io.sprintf("a proxy class with %d interfaces", $n));
    }
    for (def i in 0..$n) {
        $p = utf($p, false);
        $p.s.classInterfaces[$c][] = $p.rstr;
    }
    $p = annotation($p);
    $p = classDesc($p);
    $p.s.classSupers[$c] = $p.rint;
    $p.rint = $c;
    return $p;
}

# Append a class and give it the next handle.
func addClass(p as Parser, name as string, uid as int, flags as int) {
    def c as int init len($p.s.classNames);
    $p.s.classNames[] = $name;
    $p.s.classUids[] = $uid;
    $p.s.classFlags[] = $flags;
    $p.s.classSupers[] = -1;
    $p.s.classFieldNames[] = [];
    $p.s.classFieldTypes[] = [];
    $p.s.classFieldClasses[] = [];
    $p.s.classInterfaces[] = [];
    $p.handles[] = -$c - 1;
    return $p;
}

# A class annotation: contents up to TC_ENDBLOCKDATA, decoded and dropped.
func annotation(p as Parser) {
    def floor as int init $p.depth;
    $p = push($p, frame(M_BLOCK, DISCARD, -1));
    $p = run($p, $floor);
    return $p;
}

# TC_ENUM (tc already read): class, handle, constant name.
func enumValue(p as Parser, node as int, name as string, owner as int) {
    $p = classDesc($p);
    if ($p.rint < 0) {
        fail($p, "an enum constant needs a class");
    }
    def child as int init $p.rint;
    $p = newNode($p, K_ENUM, $child);
    def e as int init $p.rint;
    $p.handles[] = $e;
    $p = stringValue($p);
    $p.s.texts[$e] = $p.rstr;
    $p = attach($p, $node, $name, $owner, $e);
    return $p;
}

# TC_OBJECT (tc already read): class, handle, then a frame for its data.
func object(p as Parser, node as int, name as string, owner as int) {
    $p = classDesc($p);
    def c as int init $p.rint;
    if ($c < 0) {
        fail($p, "an object needs a class");
    }
    $p = newNode($p, K_OBJECT, $c);
    def n as int init $p.rint;
    $p.handles[] = $n;
    $p = attach($p, $node, $name, $owner, $n);
    def flags as int init $p.s.classFlags[$c];
    if ($flags & SC_EXTERNALIZABLE != 0) {
        if ($flags & SC_BLOCK_DATA == 0) {
            fail(
                $p,
                $p.s.classNames[$c] +
                    ": externalizable data without block data (protocol 1) is not supported");
        }
        $p = push($p, frame(M_BLOCK, $n, $c));
        return $p;
    }
    def chain as list of int init [];
    def k as int init $c;
    while ($k >= 0) {
        if (len($chain) > len($p.s.classNames)) {
            fail($p, $p.s.classNames[$c] + ": its superclass chain loops");
        }
        $chain[] = $k;
        $k = $p.s.classSupers[$k];
    }
    def f as Frame init frame(M_FIELDS, $n, $c);
    $f.chain = lists.reverse($chain);
    $p = push($p, $f);
    return $p;
}

# Bytes per element of a primitive array type, 0 for object elements.
func elementSize(type as string) {
    match ($type) {
        when "B", "Z" { return 1; }
        when "C", "S" { return 2; }
        when "I", "F" { return 4; }
        when "J", "D" { return 8; }
    }
    return 0;
}

# TC_ARRAY (tc already read): class, handle, length, then the elements -
# kept in place for a primitive array, a frame for an object array.
func array(p as Parser, node as int, name as string, owner as int) {
    $p = classDesc($p);
    def c as int init $p.rint;
    if ($c < 0 or not strings.startsWith($p.s.classNames[$c], "[")) {
        fail($p, "an array needs an array class");
    }
    $p = newNode($p, K_ARRAY, $c);
    def n as int init $p.rint;
    $p.handles[] = $n;
    need($p, 4);
    def length as int init binary.readInt("be", $p.s.data, $p.pos, 4);
    $p.pos = $p.pos + 4;
    if ($length < 0) {
        fail($p, io.sprintf("array length %d", $length));
    }
    $p.s.ints[$n] = $length;
    $p = attach($p, $node, $name, $owner, $n);
    def type as string init $p.s.classNames[$c][1..2];
    def size as int init elementSize($type);
    if ($size == 0) {
        if ($type != "L" and $type != "[") {
            fail($p, "unknown array element type " + $type);
        }
        need($p, $length);
        def f as Frame init frame(M_ELEMENTS, $n, -1);
        $f.remaining = $length;
        $p = push($p, $f);
        return $p;
    }
    need($p, $length * $size);
    $p.s.at[$n] = $p.pos;
    $p.pos = $p.pos + $length * $size;
    return $p;
}

# Block data (tc already read). Java splits long runs into blocks of 1024
# bytes, and the boundaries mean nothing, so a block that directly follows
# another of the same class joins it.
func block(p as Parser, node as int, owner as int, long as bool) {
    def n as int init 0;
    if ($long) {
        need($p, 4);
        $n = binary.readInt("be", $p.s.data, $p.pos, 4);
        $p.pos = $p.pos + 4;
        if ($n < 0) {
            fail($p, io.sprintf("block data of %d bytes", $n));
        }
    } else {
        need($p, 1);
        $n = $p.s.data[$p.pos];
        $p.pos = $p.pos + 1;
    }
    need($p, $n);
    def last as int init lastBlock($p, $node, $owner);
    if ($last > 0) {
        $p.s.segments[$last][] = $p.pos;
        $p.s.segments[$last][] = $n;
        $p.s.ints[$last] = $p.s.ints[$last] + $n;
        $p.pos = $p.pos + $n;
        return $p;
    }
    $p = newNode($p, K_BLOCK, -1);
    $p.s.segments[$p.rint] = [$p.pos, $n];
    $p.s.ints[$p.rint] = $n;
    $p.pos = $p.pos + $n;
    def child as int init $p.rint;
    $p = attach($p, $node, "", $owner, $child);
    return $p;
}

# The block node a new block joins: the target's last child when it is
# block data of the same owner, else 0.
func lastBlock(p as Parser, node as int, owner as int) {
    if ($node == DISCARD) {
        return 0;
    }
    if ($node == TOP) {
        def k as int init len($p.s.top);
        if ($k > 0 and $p.s.kinds[$p.s.top[$k - 1]] == K_BLOCK) {
            return $p.s.top[$k - 1];
        }
        return 0;
    }
    def m as int init len($p.s.children[$node]);
    if ($m == 0) {
        return 0;
    }
    def child as int init $p.s.children[$node][$m - 1];
    if ($p.s.kinds[$child] == K_BLOCK and $p.s.owners[$node][$m - 1] == $owner) {
        return $child;
    }
    return 0;
}

# A primitive field value of a type code; its node goes to rint.
func primitive(p as Parser, type as string) {
    def size as int init elementSize($type);
    need($p, $size);
    def at as int init $p.pos;
    $p.pos = $p.pos + $size;
    match ($type) {
        when "Z" {
            $p = newNode($p, K_BOOLEAN, -1);
            if ($p.s.data[$at] != 0) {
                $p.s.ints[$p.rint] = 1;
            }
        }
        when "B" {
            $p = newNode($p, K_BYTE, -1);
            $p.s.ints[$p.rint] = binary.readInt("be", $p.s.data, $at, 1);
        }
        when "C" {
            $p = newNode($p, K_CHAR, -1);
            def unit as int init binary.readUint("be", $p.s.data, $at, 2);
            $p.s.ints[$p.rint] = $unit;
            $p.s.texts[$p.rint] = charText($unit);
        }
        when "S" {
            $p = newNode($p, K_SHORT, -1);
            $p.s.ints[$p.rint] = binary.readInt("be", $p.s.data, $at, 2);
        }
        when "I" {
            $p = newNode($p, K_INT, -1);
            $p.s.ints[$p.rint] = binary.readInt("be", $p.s.data, $at, 4);
        }
        when "J" {
            $p = newNode($p, K_LONG, -1);
            $p.s.ints[$p.rint] = binary.readInt("be", $p.s.data, $at, 8);
        }
        when "F" {
            $p = newNode($p, K_FLOAT, -1);
            def fbits as int init binary.readUint("be", $p.s.data, $at, 4);
            $p.s.ints[$p.rint] = $fbits;
            if (($fbits >> 23) & 0xFF != 0xFF) {
                $p.s.floats[$p.rint] = binary.readFloat("be", $p.s.data, $at, 4);
            }
        }
        when "D" {
            $p = newNode($p, K_DOUBLE, -1);
            def dbits as int init binary.readInt("be", $p.s.data, $at, 8);
            $p.s.ints[$p.rint] = $dbits;
            if (($dbits >> 52) & 0x7FF != 0x7FF) {
                $p.s.floats[$p.rint] = binary.readFloat("be", $p.s.data, $at, 8);
            }
        }
    }
    return $p;
}

# A UTF-16 code unit as text; a lone surrogate becomes U+FFFD.
func charText(unit as int) {
    if ($unit >= 0xD800 and $unit <= 0xDFFF) {
        return "�";
    }
    return convert.fromCodepoint($unit);
}

# Modified UTF-8 (Java's DataOutput.writeUTF) to text. Most strings are
# plain UTF-8 too; the slow path handles C0 80 (U+0000) and surrogate pairs.
# Malformed input yields "￿", which `utf` turns into an error.
func mutf8(b as bytes) {
    try {
        return encoding.decode("utf-8", $b);
    } catch (e) {
        return mutf8Units($b);
    }
}

# The slow path of mutf8: decode to UTF-16 code units, then pair surrogates.
func mutf8Units(b as bytes) {
    def units as list of int init [];
    def i as int init 0;
    def n as int init len($b);
    while ($i < $n) {
        def c as int init $b[$i];
        if ($c < 0x80) {
            $units[] = $c;
            $i = $i + 1;
        } elseif ($c & 0xE0 == 0xC0 and $i + 1 < $n and $b[$i + 1] & 0xC0 == 0x80) {
            $units[] = (($c & 0x1F) << 6) | ($b[$i + 1] & 0x3F);
            $i = $i + 2;
        } elseif ($c & 0xF0 == 0xE0 and $i + 2 < $n and $b[$i + 1] & 0xC0 == 0x80 and
            $b[$i + 2] & 0xC0 == 0x80) {
            $units[] = (($c & 0x0F) << 12) | (($b[$i + 1] & 0x3F) << 6) | ($b[$i + 2] & 0x3F);
            $i = $i + 3;
        } else {
            return "￿";
        }
    }
    def out as list of string init [];
    def k as int init 0;
    while ($k < len($units)) {
        def u as int init $units[$k];
        if ($u >= 0xD800 and $u <= 0xDBFF and $k + 1 < len($units)) {
            def low as int init $units[$k + 1];
            if ($low >= 0xDC00 and $low <= 0xDFFF) {
                $out[] = convert.fromCodepoint(0x10000 + (($u - 0xD800) << 10) + ($low - 0xDC00));
                $k = $k + 2;
                continue;
            }
        }
        $out[] = charText($u);
        $k = $k + 1;
    }
    return strings.join($out, "");
}

# The writer aborted (TC_EXCEPTION): name its exception and stop.
func aborted(p as Parser, holder as int) {
    def what as string init "an exception";
    if (len($p.s.children[$holder]) > 0) {
        def ex as int init $p.s.children[$holder][0];
        if ($p.s.classOf[$ex] >= 0) {
            $what = $p.s.classNames[$p.s.classOf[$ex]];
        }
        def names as list of string init $p.s.names[$ex];
        for (def i in 0..len($names)) {
            def v as int init $p.s.children[$ex][$i];
            if ($names[$i] == "detailMessage" and $p.s.kinds[$v] == K_STRING) {
                $what = $what + ": " + $p.s.texts[$v];
            }
        }
    }
    fail($p, "the writer aborted the stream with " + $what);
}
