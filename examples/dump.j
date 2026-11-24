#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * dump example - print a serialization stream as a tree.
 *
 *   jennifer run examples/dump.j [file.ser]
 *
 * The stream may sit behind a header of its own (it is found by its magic).
 * Without an argument it dumps a small stream the JDK wrote: a HashMap
 * {"one": 1} and a java.util.Date.
 */

use encoding;
use fs;
use io;
use os;

import "../src/javaser.j" as javaser;

def const SAMPLE as string init "aced0005737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f4000000000000c770800000010000000017400036f6e65737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b020000787000000001787372000e6a6176612e7574696c2e44617465686a81014b597419030000787077080000019b76daa80078";

def data as bytes init encoding.fromText("hex", SAMPLE);
if (len(os.ARGS) > 1) {
    $data = fs.readBytes(os.ARGS[len(os.ARGS) - 1]);
}
def o as javaser.Options init javaser.defaults();
$o.offset = javaser.locate($data);
if ($o.offset < 0) {
    io.eprintf("no Java serialization stream found\n");
    exit 1;
}
def s as javaser.Stream init javaser.decodeWith($data, $o);
io.printf("%s", javaser.dump($s));
io.printf("%d values in %d bytes\n", javaser.nodeCount($s) - 1, len($data) - $o.offset);
