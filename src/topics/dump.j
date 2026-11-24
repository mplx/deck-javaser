# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# javaser - dump: the decoded stream as an indented text tree, for finding
# one's way around an unknown format. Spliced into javaser.j via include.

/** Array elements and block bytes `dump` shows before eliding the rest. */
export def const DUMP_PREVIEW as int init 8;

/**
 * The stream as an indented tree, one value per line: objects with their
 * fields and custom data, arrays, strings, primitives. A value reached a
 * second time (a Java back-reference) is printed as `-> #n`. Primitive
 * arrays and blocks show their first `DUMP_PREVIEW` elements / bytes.
 *
 * @param s {Stream} the stream
 * @return {string} the tree, lines ending in `\n`
 * @example
 *   io.printf("%s", javaser.dump($s));
 */
export func dump(s as Stream) {
    return dumpWith($s, DUMP_PREVIEW);
}

/**
 * Like `dump`, with how many array elements and block bytes to show.
 *
 * @param s {Stream} the stream
 * @param preview {int} elements / bytes per array or block, 0 or more
 * @return {string} the tree
 * @throws {Error} kind "javaser" when `preview` is negative
 */
export func dumpWith(s as Stream, preview as int) {
    if ($preview < 0) {
        throw Error{kind: "javaser", message: "dump preview must be 0 or more"};
    }
    def lines as list of string init [];
    def seen as list of bool init lists.replicate([false], len($s.kinds));
    # the open containers: node, next child, indent
    def stNode as list of int init [];
    def stNext as list of int init [];
    def depth as int init 0;
    for (def i in 0..len($s.top)) {
        def n as int init $s.top[$i];
        def label as string init io.sprintf("[%d]", $i);
        if (isContainer($s, $n) and not $seen[$n]) {
            $seen[$n] = true;
            $lines[] = label($label, headerText($s, $n));
            $stNode = [$n];
            $stNext = [0];
            $depth = 1;
            while ($depth > 0) {
                def top as int init $depth - 1;
                def parent as int init $stNode[$top];
                def k as int init $stNext[$top];
                def pad as string init strings.replicate("  ", $depth);
                if ($k >= len($s.children[$parent])) {
                    $lines[] = strings.replicate("  ", $top) + '}';
                    $depth = $top;
                    continue;
                }
                $stNext[$top] = $k + 1;
                def owner as int init $s.owners[$parent][$k];
                if ($s.names[$parent][$k] == "" and $owner >= 0) {
                    if ($k == 0 or $s.owners[$parent][$k - 1] != $owner or
                        $s.names[$parent][$k - 1] != "") {
                        $lines[] = $pad + "-- custom data of " + $s.classNames[$owner];
                    }
                }
                def child as int init $s.children[$parent][$k];
                def name as string init childLabel($s, $parent, $k);
                if (isContainer($s, $child) and not $seen[$child]) {
                    $seen[$child] = true;
                    $lines[] = $pad + label($name, headerText($s, $child));
                    if ($depth < len($stNode)) {
                        $stNode[$depth] = $child;
                        $stNext[$depth] = 0;
                    } else {
                        $stNode[] = $child;
                        $stNext[] = 0;
                    }
                    $depth = $depth + 1;
                } elseif (isContainer($s, $child)) {
                    $lines[] = $pad + label($name, refText($s, $child));
                } else {
                    $lines[] = $pad + label($name, leafText($s, $child, $preview));
                }
            }
        } elseif (isContainer($s, $n)) {
            $lines[] = label($label, refText($s, $n));
        } else {
            $lines[] = label($label, leafText($s, $n, $preview));
        }
    }
    if (len($lines) == 0) {
        return "";
    }
    return strings.join($lines, "\n") + "\n";
}

# "label: text"
func label(name as string, text as string) {
    return $name + ": " + $text;
}

# Objects and object arrays have children of their own to print.
func isContainer(s as Stream, n as int) {
    return $s.kinds[$n] == K_OBJECT or ($s.kinds[$n] == K_ARRAY and $s.at[$n] < 0);
}

# A child's label: its field name, or its index among the custom data /
# elements.
func childLabel(s as Stream, parent as int, k as int) {
    def name as string init $s.names[$parent][$k];
    if ($name != "") {
        return $name;
    }
    def index as int init 0;
    for (def i in 0..$k) {
        if ($s.names[$parent][$i] == "") {
            $index = $index + 1;
        }
    }
    return io.sprintf("[%d]", $index);
}

# The opening line of a container.
func headerText(s as Stream, n as int) {
    if ($s.kinds[$n] == K_ARRAY) {
        return io.sprintf("%s length %d #%d \{", className($s, $n), $s.ints[$n], $n);
    }
    return io.sprintf("%s #%d \{", className($s, $n), $n);
}

# A container printed before.
func refText(s as Stream, n as int) {
    return io.sprintf("-> #%d %s", $n, className($s, $n));
}

# One line for a node without children of its own.
func leafText(s as Stream, n as int, preview as int) {
    def k as int init $s.kinds[$n];
    match ($k) {
        when K_NULL { return "null"; }
        when K_STRING { return io.sprintf("%s #%d", quoted($s.texts[$n]), $n); }
        when K_ENUM { return io.sprintf("%s.%s #%d", className($s, $n), $s.texts[$n], $n); }
        when K_CLASS { return io.sprintf("class %s #%d", className($s, $n), $n); }
        when K_CLASSDESC { return "classdesc " + className($s, $n); }
        when K_BLOCK {
            def b as bytes init asBytes($s, $n);
            return io.sprintf("block[%d] %s", len($b), hexPreview($b, $preview));
        }
        when K_ARRAY {
            return io.sprintf(
                "%s[%d] #%d %s",
                elementType($s, $n),
                $s.ints[$n],
                $n,
                arrayPreview($s, $n, $preview));
        }
        when K_FLOAT, K_DOUBLE {
            if (isFinite($s, $n)) {
                return KIND_NAMES[$k] + " " + convert.toString($s.floats[$n]);
            }
            return io.sprintf("%s bits 0x%d|base=16", KIND_NAMES[$k], $s.ints[$n]);
        }
        when K_CHAR { return io.sprintf("char %s", quoted($s.texts[$n])); }
        when K_BOOLEAN { return io.sprintf("boolean %t", $s.ints[$n] != 0); }
    }
    return KIND_NAMES[$k] + " " + convert.toString($s.ints[$n]);
}

# Text in double quotes, with quotes, backslashes and control characters
# escaped.
func quoted(text as string) {
    def t as string init strings.replace($text, "\\", "\\\\");
    $t = strings.replace($t, "\"", "\\\"");
    $t = strings.replace($t, "\n", "\\n");
    $t = strings.replace($t, "\r", "\\r");
    $t = strings.replace($t, "\t", "\\t");
    $t = strings.replace($t, "\0", "\\0");
    return "\"" + $t + "\"";
}

# The first bytes in hex, "..." when there are more.
func hexPreview(b as bytes, preview as int) {
    if (len($b) <= $preview) {
        return encoding.toText("hex", $b);
    }
    return encoding.toText("hex", $b[0..$preview]) + "...";
}

# The first elements of a primitive array.
func arrayPreview(s as Stream, n as int, preview as int) {
    def t as string init elementType($s, $n);
    def count as int init $s.ints[$n];
    def shown as int init $count;
    if ($shown > $preview) {
        $shown = $preview;
    }
    def items as list of string init [];
    if ($t == "float" or $t == "double") {
        def bits as list of int init floatArrayBits($s, $n);
        def size as int init 8;
        if ($t == "float") {
            $size = 4;
        }
        for (def i in 0..$shown) {
            $items[] = floatText($s, $s.at[$n] + $i * $size, $size, $bits[$i]);
        }
    } else {
        def values as list of int init ints($s, $n);
        for (def i in 0..$shown) {
            $items[] = convert.toString($values[$i]);
        }
    }
    if ($count > $shown) {
        $items[] = "...";
    }
    return "[" + strings.join($items, ", ") + "]";
}

# One float element as text: its value, or NaN / Inf.
func floatText(s as Stream, at as int, size as int, bits as int) {
    def mask as int init 0x7FF;
    def shift as int init 52;
    if ($size == 4) {
        $mask = 0xFF;
        $shift = 23;
    }
    if (($bits >> $shift) & $mask == $mask) {
        return "NaN/Inf";
    }
    return convert.toString(binary.readFloat("be", $s.data, $at, $size));
}
