#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * navigate example - read a java.util.HashMap and a java.util.Date the JDK
 * serialized: fields, custom data (HashMap's buckets and entries, Date's
 * milliseconds) and a boxed Integer.
 *
 *   jennifer run examples/navigate.j
 */

use binary;
use encoding;
use io;
use time;

import "../src/javaser.j" as javaser;

def const SAMPLE as string init "aced0005737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f4000000000000c770800000010000000017400036f6e65737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b020000787000000001787372000e6a6176612e7574696c2e44617465686a81014b597419030000787077080000019b76daa80078";

def s as javaser.Stream init javaser.decode(encoding.fromText("hex", SAMPLE));
def top as list of int init javaser.contents($s);

# HashMap: two fields, then writeObject's data - buckets and size as ints,
# then each key and value as objects
def hashMap as int init $top[0];
io.printf(
    "%s, load factor %f\n",
    javaser.className($s, $hashMap),
    javaser.asFloat($s, javaser.field($s, $hashMap, "loadFactor")));
def parts as list of int init javaser.custom($s, $hashMap);
def head as bytes init javaser.asBytes($s, $parts[0]);
def size as int init binary.readInt("be", $head, 4, 4);
for (def i in 0..$size) {
    def key as int init $parts[1 + 2 * $i];
    def value as int init $parts[2 + 2 * $i];
    io.printf(
        "  %s = %d (%s)\n",
        javaser.asString($s, $key),
        javaser.asInt($s, javaser.field($s, $value, "value")),
        javaser.className($s, $value));
}

# Date: no fields, writeObject writes the milliseconds since 1970 as a long
def date as int init $top[1];
def millis as int init binary.readInt(
    "be",
    javaser.asBytes($s, javaser.custom($s, $date)[0]),
    0,
    8);
io.printf("%s %s\n", javaser.className($s, $date), time.iso(time.fromUnixMilliseconds($millis)));
