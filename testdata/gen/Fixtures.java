// SPDX-License-Identifier: LGPL-3.0-only
// SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
//
// Writes the test streams of @mplx/javaser with the JDK's own
// ObjectOutputStream, one file per fixture, into the directory given:
//
//   javac -d /tmp/fx Fixtures.java && java -Xss64m -cp /tmp/fx Fixtures /tmp/fx/out
//
// testdata/gen/embed.j turns the files into src/topics/fixtures/streams_test.j.
import java.io.*;
import java.lang.reflect.*;
import java.util.*;

public class Fixtures {
    static class Prims implements Serializable {
        private static final long serialVersionUID = 1L;
        boolean z = true;
        byte b = -5;
        char c = 'é';
        short s = -300;
        int i = 123456;
        long j = -9000000000000000L;
        float f = 1.5f;
        double d = Math.PI;
        double nan = Double.NaN;
        float inf = Float.POSITIVE_INFINITY;
        String str = "hello";
        Object nothing = null;
    }

    static class WithWriteObject implements Serializable {
        private static final long serialVersionUID = 2L;
        int x = 7;
        private void writeObject(ObjectOutputStream out) throws IOException {
            out.defaultWriteObject();
            out.writeInt(42);
            out.writeUTF("tail");
            out.writeObject("obj");
            byte[] big = new byte[3000];
            for (int k = 0; k < big.length; k++) big[k] = (byte) k;
            out.write(big);
        }
    }

    static class Ext implements Externalizable {
        private static final long serialVersionUID = 3L;
        public Ext() {}
        public void writeExternal(ObjectOutput out) throws IOException {
            out.writeInt(7);
            out.writeObject("name");
            out.writeDouble(2.5);
        }
        public void readExternal(ObjectInput in) {}
    }

    static class Base implements Serializable {
        private static final long serialVersionUID = 4L;
        int a = 1;
        String name = "base";
    }

    static class Derived extends Base {
        private static final long serialVersionUID = 5L;
        int a = 2;
        long extra = 3L;
    }

    enum Color { RED, GREEN }

    static class Node implements Serializable {
        private static final long serialVersionUID = 6L;
        int v;
        Node next;
    }

    static class Handler implements InvocationHandler, Serializable {
        private static final long serialVersionUID = 7L;
        public Object invoke(Object p, Method m, Object[] a) { return null; }
    }

    static class Failing implements Serializable {
        private static final long serialVersionUID = 8L;
        int before = 1;
        private void writeObject(ObjectOutputStream out) throws IOException {
            out.defaultWriteObject();
            throw new IOException("refused on purpose");
        }
    }

    interface Body { void write(ObjectOutputStream out) throws IOException; }

    static void write(File dir, String name, Body body) throws IOException {
        try (ObjectOutputStream out = new ObjectOutputStream(
                new FileOutputStream(new File(dir, name + ".ser")))) {
            body.write(out);
        }
    }

    public static void main(String[] args) throws Exception {
        File dir = new File(args[0]);
        dir.mkdirs();

        write(dir, "primitives", out -> out.writeObject(new Prims()));

        write(dir, "strings", out -> {
            String shared = "twice";
            ArrayList<String> list = new ArrayList<>(Arrays.asList(
                "", "ascii", "nul\0inside", "äöü€",
                "emoji 😀", "日本語", shared, shared));
            out.writeObject(list);
            StringBuilder sb = new StringBuilder();
            for (int k = 0; k < 70000; k++) sb.append((char) ('a' + k % 26));
            out.writeObject(sb.toString());
        });

        write(dir, "arrays", out -> {
            out.writeObject(new int[] {1, -2, 3});
            out.writeObject(new byte[] {0, 127, -128, -1});
            out.writeObject(new long[] {Long.MIN_VALUE, 0L, Long.MAX_VALUE});
            out.writeObject(new double[] {1.0, -0.5, Double.NaN});
            out.writeObject(new boolean[] {true, false});
            out.writeObject(new char[] {'J', 'é'});
            out.writeObject(new short[] {-1, 32767});
            out.writeObject(new float[] {0.25f});
            out.writeObject(new String[] {"a", null, "a"});
            out.writeObject(new int[][] {{1, 2}, {3}});
            out.writeObject(new Object[0]);
        });

        write(dir, "custom", out -> out.writeObject(new WithWriteObject()));
        write(dir, "external", out -> out.writeObject(new Ext()));
        write(dir, "inherit", out -> out.writeObject(new Derived()));

        write(dir, "enums", out -> {
            out.writeObject(new ArrayList<>(Arrays.asList(Color.RED, Color.GREEN, Color.RED)));
            out.writeObject(String.class);
            out.writeObject(int[].class);
        });

        write(dir, "collections", out -> {
            HashMap<String, Integer> map = new HashMap<>();
            map.put("one", 1);
            out.writeObject(map);
            out.writeObject(new Date(1767225600000L));
        });

        write(dir, "deep", out -> {
            Node head = null;
            for (int k = 5000; k > 0; k--) {
                Node n = new Node();
                n.v = k;
                n.next = head;
                head = n;
            }
            out.writeObject(head);
        });

        write(dir, "primitivesTop", out -> {
            out.writeInt(0x01020304);
            out.writeUTF("block");
            out.writeObject("after");
        });

        write(dir, "reset", out -> {
            out.writeObject("a");
            out.reset();
            out.writeObject("a");
        });

        write(dir, "proxy", out -> out.writeObject(Proxy.newProxyInstance(
            Fixtures.class.getClassLoader(), new Class<?>[] {Runnable.class}, new Handler())));

        write(dir, "exception", out -> {
            try {
                out.writeObject(new Failing());
            } catch (IOException expected) {
                // the stream now ends in TC_EXCEPTION
            }
        });
    }
}
