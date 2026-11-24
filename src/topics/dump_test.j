# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

# javaser - dump tests. Spliced into javaser_test.j via include.

func testDumpPrintsFieldsAndValues() {
    def text as string init dump(decode(fixture("primitives")));
    def lines as list of string init strings.split($text, "\n");
    testing.assertEqual($lines[0], '[0]: Fixtures$Prims #3 {');
    testing.assertContains($text, "\n  b: byte -5\n");
    testing.assertContains($text, "\n  c: char \"é\"\n");
    testing.assertContains($text, "\n  nan: double bits 0x7ff8000000000000\n");
    testing.assertContains($text, "\n  z: boolean true\n");
    testing.assertContains($text, "\n  nothing: null\n");
    testing.assertContains($text, "\n  str: \"hello\" #");
    testing.assertEqual(strings.endsWith($text, "\n\}\n"), true);
}

func testDumpShowsCustomDataAndBackReferences() {
    def text as string init dump(decode(fixture("custom")));
    testing.assertContains($text, "  -- custom data of Fixtures$WithWriteObject\n");
    testing.assertContains($text, "  [2]: block[3000] 0001020304050607...\n");
    def again as string init dump(decode(streamOf("73" + CLASS_A + "70 71007e0001")));
    testing.assertEqual($again, "[0]: A #1 \{\n\}\n[1]: -> #1 A\n");
}

func testDumpPreviewsArrays() {
    def s as Stream init decode(fixture("arrays"));
    testing.assertContains(dumpWith($s, 2), "[0]: int[3] #1 [1, -2, ...]\n");
    testing.assertContains(dump($s), "[3]: double[3] #4 [1.0, -0.5, NaN/Inf]\n");
    testing.assertContains(dumpWith($s, 0), "[7]: float[1] #8 [...]\n");
    testing.assertThrowsArgs("dumpWith", [$s, -1], "javaser");
}

func testDumpEscapesText() {
    def text as string init dump(decode(fixture("strings")));
    testing.assertContains($text, "\"nul\\0inside\"");
    testing.assertEqual(dump(decode(streamOf(""))), "");
}
