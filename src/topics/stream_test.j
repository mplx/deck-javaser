# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# javaser - stream tests: decoding, its limits and its errors. Spliced into
# javaser_test.j via include.

# A class descriptor `A` (uid 1, serializable) with no fields and no
# superclass, as hex: handle 0x7E0000 when it is the first thing written.
def const CLASS_A as string init "72000141000000000000000102000078";

/**
 * Bytes from hex, spaces ignored.
 *
 * @param hex {string} the hex digits
 * @return {bytes} the bytes
 */
func hexBytes(hex as string) {
    return encoding.fromText("hex", strings.replace($hex, " ", ""));
}

/**
 * Bytes from hex behind the stream header AC ED 00 05.
 *
 * @param hex {string} the stream's contents in hex
 * @return {bytes} the stream
 */
func streamOf(hex as string) {
    return hexBytes("aced0005" + $hex);
}

/**
 * Assert that decoding fails with a kind and a message part.
 *
 * @param b {bytes} the stream
 * @param kind {string} the error kind expected
 * @param want {string} part of the message expected
 */
func refused(b as bytes, kind as string, want as string) {
    def threw as bool init false;
    try {
        decode($b);
    } catch (e) {
        $threw = true;
        testing.assertEqual($e.kind, $kind);
        testing.assertContains($e.message, $want);
    }
    testing.assertEqual($threw, true);
}

/**
 * Assert that decoding with options fails with a kind.
 *
 * @param b {bytes} the stream
 * @param o {Options} the options
 * @param kind {string} the error kind expected
 */
func refusedWith(b as bytes, o as Options, kind as string) {
    def threw as bool init false;
    try {
        decodeWith($b, $o);
    } catch (e) {
        $threw = true;
        testing.assertEqual($e.kind, $kind);
    }
    testing.assertEqual($threw, true);
}

func testDefaultsAreTheConstants() {
    def o as Options init defaults();
    testing.assertEqual($o.offset, 0);
    testing.assertEqual($o.maxNodes, DEFAULT_MAX_NODES);
    testing.assertEqual($o.maxDepth, DEFAULT_MAX_DEPTH);
}

func testAnEmptyStreamHasNoContents() {
    def s as Stream init decode(streamOf(""));
    testing.assertEqual(contents($s), []);
    testing.assertEqual(nodeCount($s), 1);
    testing.assertEqual(typeOf($s, 0), "null");
}

func testWhatIsNotAStreamIsRefused() {
    refused(hexBytes(""), "javaser", "truncated");
    refused(hexBytes("cafebabe"), "javaser", "no AC ED magic");
    refused(hexBytes("aced0004"), "javaser", "stream version 4");
}

func testTruncatedStreamsAreRefused() {
    def b as bytes init fixture("primitives");
    for (def cut in [5, 20, 60, len($b) - 1]) {
        refused($b[0..$cut], "javaser", "truncated");
    }
}

func testMalformedStreamsAreRefused() {
    refused(streamOf("6f"), "javaser", "unknown type code 0x6f");
    refused(streamOf("71007e0005"), "javaser", "unknown handle 0x7e0005");
    refused(streamOf("78"), "javaser", "end of block data outside custom data");
    refused(streamOf("7300"), "javaser", "expected a class descriptor");
    refused(streamOf("7370"), "javaser", "an object needs a class");
    refused(streamOf("757070"), "javaser", "an array needs an array class");
    refused(streamOf("7400 02c041"), "javaser", "malformed modified UTF-8");
    # a field type code that does not exist
    refused(
        streamOf("7372000141000000000000000102000151000178"),
        "javaser",
        "unknown field type code Q");
    # an array with a negative length
    refused(
        streamOf("7572 00025b49 0000000000000001 02 0000 78 70 ffffffff"),
        "javaser",
        "array length -1");
}

func testBlockDataOnlyStandsInCustomData() {
    # class A with one Object field "o", then block data as its value
    def desc as string init "72000141000000000000000102 0001 4c 00016f 74 0012 4c6a6176612f6c616e672f4f626a6563743b 78 70";
    refused(streamOf("73" + $desc + "770100"), "javaser", "block data where a field value");
    refused(streamOf("73" + $desc + "79"), "javaser", "a reset where a field value");
}

func testASuperclassLoopIsRefused() {
    # A names itself (handle 0x7E0000) as its superclass
    refused(
        streamOf("73 7200014100000000000000010200007871007e0000"),
        "javaser",
        "superclass chain loops");
}

func testAClassReferenceMustNameAClass() {
    refused(streamOf("740001 41 73 71007e0000"), "javaser", "names no class");
}

func testOptionsAreChecked() {
    def b as bytes init fixture("primitives");
    def o as Options init defaults();
    $o.offset = -1;
    refusedWith($b, $o, "javaser");
    $o.offset = len($b) + 1;
    refusedWith($b, $o, "javaser");
    $o = defaults();
    $o.maxNodes = 0;
    refusedWith($b, $o, "javaser");
    $o = defaults();
    $o.maxDepth = 0;
    refusedWith($b, $o, "javaser");
}

func testCapsAreLimits() {
    def b as bytes init fixture("deep");
    def o as Options init defaults();
    $o.maxDepth = 100;
    refusedWith($b, $o, "limit");
    $o = defaults();
    $o.maxNodes = 50;
    refusedWith($b, $o, "limit");
}

func testLocateFindsAStreamBehindAHeader() {
    def header as bytes init encoding.encode("utf-8", "SomeApp 1.2.00");
    def b as bytes init binary.concat(binary.concat($header, binary.make(50)), fixture("reset"));
    testing.assertEqual(locate($b), 64);
    testing.assertEqual(locate(hexBytes("00aced0004")), -1);
    def o as Options init defaults();
    $o.offset = locate($b);
    def s as Stream init decodeWith($b, $o);
    testing.assertEqual($s.offset, 64);
    testing.assertEqual(len(contents($s)), 2);
}

func testAnAbortedStreamNamesTheException() {
    refused(
        fixture("exception"),
        "javaser",
        "aborted the stream with java.io.IOException: refused on purpose");
}

func testADeepChainDecodesWithoutRecursion() {
    def s as Stream init decode(fixture("deep"));
    def n as int init contents($s)[0];
    def count as int init 0;
    while ($n != 0) {
        $count = $count + 1;
        testing.assertEqual(asInt($s, field($s, $n, "v")), $count);
        $n = field($s, $n, "next");
    }
    testing.assertEqual($count, 5000);
}

func testAResetForgetsTheHandles() {
    def s as Stream init decode(fixture("reset"));
    def top as list of int init contents($s);
    testing.assertEqual(len($top), 2);
    testing.assertEqual(asString($s, $top[0]), "a");
    testing.assertEqual(asString($s, $top[1]), "a");
    testing.assertEqual($top[0] != $top[1], true);
}

func testABackReferenceIsOneNode() {
    def s as Stream init decode(streamOf("73" + CLASS_A + "70 71007e0001"));
    def top as list of int init contents($s);
    testing.assertEqual($top[0], $top[1]);
    testing.assertEqual(className($s, $top[0]), "A");
}

func testAClassDescriptorAsAValue() {
    def s as Stream init decode(streamOf(CLASS_A + "70 71007e0000"));
    def top as list of int init contents($s);
    testing.assertEqual(typeOf($s, $top[0]), "classdesc");
    testing.assertEqual(typeOf($s, $top[1]), "classdesc");
    testing.assertEqual(className($s, $top[1]), "A");
}

func testBlocksJoinAcrossJavaSplits() {
    # writeObject wrote 3000 bytes, which Java splits into 1024-byte blocks
    def s as Stream init decode(fixture("custom"));
    def parts as list of int init custom($s, contents($s)[0]);
    testing.assertEqual(len($parts), 3);
    def big as bytes init asBytes($s, $parts[2]);
    testing.assertEqual(len($big), 3000);
    testing.assertEqual(length($s, $parts[2]), 3000);
    for (def i in [0, 255, 256, 1023, 1024, 2999]) {
        testing.assertEqual($big[$i], $i % 256);
    }
}

func testModifiedUtf8() {
    def s as Stream init decode(fixture("strings"));
    def arrayList as int init contents($s)[0];
    def texts as list of string init [];
    for (def n in custom($s, $arrayList)) {
        if (typeOf($s, $n) == "string") {
            $texts[] = asString($s, $n);
        }
    }
    testing.assertEqual($texts[2], "nul\0inside");
    testing.assertEqual($texts[3], "äöü€");
    testing.assertEqual($texts[4], "emoji \U0001F600");
    testing.assertEqual($texts[5], "日本語");
    testing.assertEqual(mutf8(hexBytes("eda080")), "�");
    testing.assertEqual(mutf8(hexBytes("41c080")), "A\0");
}

func testALongString() {
    def s as Stream init decode(fixture("strings"));
    def long as int init contents($s)[1];
    testing.assertEqual(length($s, $long), 70000);
    testing.assertEqual(asString($s, $long)[0..3], "abc");
}
