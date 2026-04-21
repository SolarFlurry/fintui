<p align="center">
    <img src="./assets/logo.png" width="30%" />
</p>

---

# Fintui

a simple Zig TUI library

> [!WARNING]
> Fintui is nowhere near a complete stage to be used

Fintui supports only Zig 0.16.x

Setup example:
```zig
const std = @import("std");
const fintui = @import("fintui");

// Juicy Main!
pub fn main(init: std.process.Init) !void {
    // setup frame arena
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    // setup stdout and stdin
    // buffered write is useful to prevent partially blank frames
    var stdout_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const writer = &stdout.interface;

    const stdin = std.Io.File.stdin();

    // setup fintui screen!
    var screen: fintui.Screen = .init(
        init.gpa,
        arena.allocator(),
        writer,
        init.io,
    );
    defer screen.deinit() catch {};

    // main loop
    while (true) {
        defer _ = arena.reset(.free_all); // reset frame arena per frame
        defer screen.render() catch {}; // render screen

        const delta = screen.delta(init.io); // call this function ONCE a frame to get deltatime
        
        // render a string to the screen!
        screen.writeString(0, 0, "Some text!", .{});
    }
}
```

## Installation:

Run `zig fetch`.

```sh
zig fetch --save=fintui git+https://github.com/SolarFlurry/fintui
```

Add this to the `build.zig`:

```zig
const fintui = b.dependency("fintui", .{});
exe.root_module.addImport("fintui", fintui.module("fintui"));
```

## Features:

- Event reporting (key presses, mouse)
- Buffer diffing rendering

For a demo examples, see the [`examples`](./examples/) directory.
