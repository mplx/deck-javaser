# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# javaser - values tests: the accessors on streams the JDK wrote. Spliced
# into javaser_test.j via include.

/**
 * A fixture, decoded.
 *
 * @param name {string} the fixture
 * @return {Stream} the decoded stream
 */
func streamOfFixture(name as string) {
    return decode(fixture($name));
}

/**
 * Assert that an accessor refuses a node with kind "javaser".
 *
 * @param name {string} the accessor
 * @param s {Stream} the stream
 * @param n {int} the node it must refuse
 */
func wrongNode(name as string, s as Stream, n as int) {
    testing.assertThrowsArgs($name, [$s, $n], "javaser");
}

func testPrimitiveFields() {
    def s as Stream init streamOfFixture("primitives");
    def o as int init contents($s)[0];
    testing.assertEqual(typeOf($s, $o), "object");
    testing.assertEqual(className($s, $o), "Fixtures$Prims");
    testing.assertEqual(serialVersionUid($s, $o), 1);
    testing.assertEqual(classChain($s, $o), ["Fixtures$Prims"]);
    testing.assertEqual(
        fieldNames($s, $o),
        ["b", "c", "d", "f", "i", "inf", "j", "nan", "s", "z", "nothing", "str"]);
    testing.assertEqual(asInt($s, field($s, $o, "b")), -5);
    testing.assertEqual(asInt($s, field($s, $o, "s")), -300);
    testing.assertEqual(asInt($s, field($s, $o, "i")), 123456);
    testing.assertEqual(asInt($s, field($s, $o, "j")), -9000000000000000);
    testing.assertEqual(asInt($s, field($s, $o, "c")), 0xE9);
    testing.assertEqual(asString($s, field($s, $o, "c")), "é");
    testing.assertEqual(typeOf($s, field($s, $o, "c")), "char");
    testing.assertEqual(asBool($s, field($s, $o, "z")), true);
    testing.assertEqual(asFloat($s, field($s, $o, "f")), 1.5);
    testing.assertEqual(asFloat($s, field($s, $o, "d")), 3.141592653589793);
    testing.assertEqual(asString($s, field($s, $o, "str")), "hello");
    testing.assertEqual(field($s, $o, "nothing"), 0);
    testing.assertEqual(has($s, $o, "str"), true);
    testing.assertEqual(has($s, $o, "missing"), false);
    testing.assertEqual(has($s, $o, ""), false);
}

func testNonFiniteFloats() {
    def s as Stream init streamOfFixture("primitives");
    def o as int init contents($s)[0];
    def nan as int init field($s, $o, "nan");
    def inf as int init field($s, $o, "inf");
    testing.assertEqual(isFinite($s, $nan), false);
    testing.assertEqual(isFinite($s, $inf), false);
    testing.assertEqual(isFinite($s, field($s, $o, "d")), true);
    testing.assertEqual(floatBits($s, $nan), 0x7FF8000000000000);
    testing.assertEqual(floatBits($s, $inf), 0x7F800000);
    testing.assertEqual(floatBits($s, field($s, $o, "f")), 0x3FC00000);
    wrongNode("asFloat", $s, $nan);
    wrongNode("floatBits", $s, field($s, $o, "i"));
}

func testPrimitiveArrays() {
    def s as Stream init streamOfFixture("arrays");
    def a as list of int init contents($s);
    testing.assertEqual(ints($s, $a[0]), [1, -2, 3]);
    testing.assertEqual(ints($s, $a[1]), [0, 127, -128, -1]);
    testing.assertEqual(asBytes($s, $a[1]), hexBytes("007f80ff"));
    testing.assertEqual(ints($s, $a[2]), [-9223372036854775807 - 1, 0, 9223372036854775807]);
    testing.assertEqual(ints($s, $a[4]), [1, 0]);
    testing.assertEqual(ints($s, $a[5]), [74, 0xE9]);
    testing.assertEqual(ints($s, $a[6]), [-1, 32767]);
    testing.assertEqual(floats($s, $a[7]), [0.25]);
    testing.assertEqual(
        floatArrayBits($s, $a[3]),
        [0x3FF0000000000000, -4620693217682128896, 0x7FF8000000000000]);
    testing.assertThrowsArgs("floats", [$s, $a[3]], "javaser");
    def types as list of string init [];
    for (def n in $a) {
        $types[] = elementType($s, $n);
    }
    testing.assertEqual(
        $types,
        [
            "int",
            "byte",
            "long",
            "double",
            "boolean",
            "char",
            "short",
            "float",
            "object",
            "array",
            "object"
        ]);
    testing.assertEqual(length($s, $a[0]), 3);
    testing.assertEqual(className($s, $a[0]), "[I");
}

func testObjectArrays() {
    def s as Stream init streamOfFixture("arrays");
    def a as list of int init contents($s);
    def strs as list of int init elements($s, $a[8]);
    testing.assertEqual(len($strs), 3);
    testing.assertEqual($strs[0], $strs[2]);
    testing.assertEqual($strs[1], 0);
    testing.assertEqual(className($s, $a[8]), "[Ljava.lang.String;");
    def rows as list of int init elements($s, $a[9]);
    testing.assertEqual(ints($s, $rows[0]), [1, 2]);
    testing.assertEqual(ints($s, $rows[1]), [3]);
    testing.assertEqual(elements($s, $a[10]), []);
    testing.assertEqual(length($s, $a[10]), 0);
    wrongNode("elements", $s, $a[0]);
}

func testCustomData() {
    def s as Stream init streamOfFixture("custom");
    def o as int init contents($s)[0];
    testing.assertEqual(asInt($s, field($s, $o, "x")), 7);
    def parts as list of int init customOf($s, $o, "Fixtures$WithWriteObject");
    testing.assertEqual($parts, custom($s, $o));
    def head as bytes init asBytes($s, $parts[0]);
    testing.assertEqual(binary.readInt("be", $head, 0, 4), 42);
    testing.assertEqual(binary.readUint("be", $head, 4, 2), 4);
    testing.assertEqual(encoding.decode("utf-8", $head[6..10]), "tail");
    testing.assertEqual(asString($s, $parts[1]), "obj");
    testing.assertEqual(customOf($s, $o, "java.lang.Object"), []);
}

func testExternalizableData() {
    def s as Stream init streamOfFixture("external");
    def o as int init contents($s)[0];
    testing.assertEqual(fieldNames($s, $o), []);
    def parts as list of int init custom($s, $o);
    testing.assertEqual(len($parts), 3);
    testing.assertEqual(binary.readInt("be", asBytes($s, $parts[0]), 0, 4), 7);
    testing.assertEqual(asString($s, $parts[1]), "name");
    testing.assertEqual(binary.readFloat("be", asBytes($s, $parts[2]), 0, 8), 2.5);
    testing.assertEqual(($s.classFlags[$s.classOf[$o]] & SC_EXTERNALIZABLE) != 0, true);
    testing.assertEqual(($s.classFlags[$s.classOf[$o]] & SC_BLOCK_DATA) != 0, true);
}

func testShadowedFields() {
    def s as Stream init streamOfFixture("inherit");
    def o as int init contents($s)[0];
    testing.assertEqual(classChain($s, $o), ["Fixtures$Base", "Fixtures$Derived"]);
    testing.assertEqual(fieldNames($s, $o), ["a", "name", "a", "extra"]);
    testing.assertEqual(asInt($s, field($s, $o, "a")), 2);
    testing.assertEqual(asInt($s, fieldOf($s, $o, "Fixtures$Base", "a")), 1);
    testing.assertEqual(asInt($s, fieldOf($s, $o, "Fixtures$Derived", "a")), 2);
    testing.assertEqual(asString($s, field($s, $o, "name")), "base");
    testing.assertThrowsArgs("fieldOf", [$s, $o, "Fixtures$Derived", "name"], "javaser");
    testing.assertThrowsArgs("field", [$s, $o, "nope"], "javaser");
}

func testEnumsAndClasses() {
    def s as Stream init streamOfFixture("enums");
    def top as list of int init contents($s);
    def items as list of int init custom($s, $top[0]);
    testing.assertEqual(typeOf($s, $items[1]), "enum");
    testing.assertEqual(className($s, $items[1]), "Fixtures$Color");
    testing.assertEqual(asString($s, $items[1]), "RED");
    testing.assertEqual(asString($s, $items[2]), "GREEN");
    testing.assertEqual($items[1], $items[3]);
    testing.assertEqual(($s.classFlags[$s.classOf[$items[1]]] & SC_ENUM) != 0, true);
    testing.assertEqual(typeOf($s, $top[1]), "class");
    testing.assertEqual(className($s, $top[1]), "java.lang.String");
    testing.assertEqual(className($s, $top[2]), "[I");
}

func testJdkCollections() {
    def s as Stream init streamOfFixture("collections");
    def top as list of int init contents($s);
    def hashMap as int init $top[0];
    testing.assertEqual(asFloat($s, field($s, $hashMap, "loadFactor")), 0.75);
    def entries as list of int init custom($s, $hashMap);
    testing.assertEqual(binary.readInt("be", asBytes($s, $entries[0]), 4, 4), 1);
    testing.assertEqual(asString($s, $entries[1]), "one");
    testing.assertEqual(asInt($s, field($s, $entries[2], "value")), 1);
    testing.assertEqual(classChain($s, $entries[2]), ["java.lang.Number", "java.lang.Integer"]);
    def date as bytes init asBytes($s, custom($s, $top[1])[0]);
    testing.assertEqual(binary.readInt("be", $date, 0, 8), 1767225600000);
    testing.assertEqual(asInt($s, field($s, $hashMap, "threshold")), 12);
}

func testProxies() {
    def s as Stream init streamOfFixture("proxy");
    def p as int init contents($s)[0];
    testing.assertEqual(className($s, $p), "$Proxy");
    testing.assertEqual(interfaces($s, $p), ["java.lang.Runnable"]);
    testing.assertEqual(classChain($s, $p), ["java.lang.reflect.Proxy", "$Proxy"]);
    testing.assertEqual(className($s, field($s, $p, "h")), "Fixtures$Handler");
    testing.assertEqual(interfaces($s, field($s, $p, "h")), []);
}

func testTopLevelPrimitives() {
    def s as Stream init streamOfFixture("primitivesTop");
    def top as list of int init contents($s);
    testing.assertEqual(typeOf($s, $top[0]), "block");
    def b as bytes init asBytes($s, $top[0]);
    testing.assertEqual(binary.readInt("be", $b, 0, 4), 0x01020304);
    testing.assertEqual(encoding.decode("utf-8", $b[6..11]), "block");
    testing.assertEqual(asString($s, $top[1]), "after");
}

func testObjectsOf() {
    def s as Stream init streamOfFixture("deep");
    testing.assertEqual(len(objectsOf($s, "Fixtures$Node")), 5000);
    testing.assertEqual(objectsOf($s, "Fixtures$Other"), []);
}

func testAccessorsRefuseTheWrongNode() {
    def s as Stream init streamOfFixture("primitives");
    def o as int init contents($s)[0];
    def str as int init field($s, $o, "str");
    def i as int init field($s, $o, "i");
    for (def name in [
        "typeOf",
        "className",
        "classChain",
        "fieldNames",
        "custom",
        "serialVersionUid",
        "interfaces"
    ]) {
        wrongNode($name, $s, nodeCount($s));
        wrongNode($name, $s, -1);
    }
    wrongNode("asInt", $s, $str);
    wrongNode("asBool", $s, $i);
    wrongNode("asString", $s, $i);
    wrongNode("asBytes", $s, $i);
    wrongNode("length", $s, $i);
    wrongNode("ints", $s, $o);
    wrongNode("floats", $s, $o);
    wrongNode("floatArrayBits", $s, $o);
    wrongNode("elementType", $s, $o);
    testing.assertThrowsArgs("customOf", [$s, -1, "x"], "javaser");
    testing.assertThrowsArgs("has", [$s, -1, "x"], "javaser");
    testing.assertEqual(className($s, $i), "");
    testing.assertEqual(classChain($s, $i), []);
    testing.assertEqual(serialVersionUid($s, $i), 0);
}
