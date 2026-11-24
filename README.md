# @mplx/javaser

[![test](https://github.com/mplx/deck-javaser/actions/workflows/test.yml/badge.svg)](https://github.com/mplx/deck-javaser/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://mplx.github.io/deck-javaser/)
[![release](https://img.shields.io/github/v/release/mplx/deck-javaser)](https://github.com/mplx/deck-javaser/releases/latest)

Decode Java™ Object Serialization streams - what `ObjectOutputStream` writes,
found in `.ser` files, application project files, caches and RMI payloads -
in a [Jennifer](https://jennifer-lang.dev/) program, without a JVM and
without running any Java code. Objects, arrays, strings, enums, proxies,
back-references and custom `writeObject` / `writeExternal` data become a
graph of numbered nodes to navigate, or a readable tree.

**[Documentation](https://mplx.github.io/deck-javaser/)**

## Install

```sh
jvc add @mplx/javaser
```

This vendors the deck to `vendor/mplx/javaser/`. Without `jvc`, unpack the
`src/` subtree of a release archive (`mplx-javaser-<version>.tar.gz`) there.

## Usage

```jennifer
import "@mplx/javaser/" as javaser;

def s as javaser.Stream init javaser.decode(fs.readBytes("objects.ser"));
io.printf("%s", javaser.dump($s));

def first as int init javaser.contents($s)[0];
io.printf("%s\n", javaser.className($s, $first));
```

## Requirements

Jennifer 0.28.0 or newer. Pure computation: no network, files only as the
caller reads them.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/javaser_test.j     # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

The test streams are written by the JDK: `testdata/gen/Fixtures.java`
writes them, `testdata/gen/embed.j` embeds them in
`src/topics/fixtures/streams_test.j`.

## Trademarks

Java™ is a trademark of Oracle and/or its affiliates; OpenJDK™ is a trademark
of Oracle America, Inc. Other product and company names may be trademarks of
their respective owners. They are used only to identify the products this deck
works with. This deck is an independent project, not affiliated with,
sponsored or endorsed by Oracle.

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`.
