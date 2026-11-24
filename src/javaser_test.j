# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.28.0

/**
 * White-box tests: jennifer test src/javaser_test.j (from the deck root)
 *
 * The streams in `topics/fixtures/streams_test.j` were written by the JDK
 * itself (testdata/gen/Fixtures.java); malformed streams are built in the
 * tests from hex. Everything lives under src/, so the overlays also run
 * where jvc runs them: from a copy of src/ alone.
 */
use compress;
use testing;

include "topics/fixtures/streams_test.j";
include "topics/stream_test.j";
include "topics/values_test.j";
include "topics/dump_test.j";
