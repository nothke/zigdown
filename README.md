# zigdown engine

A little OpenGL engine written in zig, inspired by my C++ engine used for [Shakedown Rally](https://nothke.itch.io/shakedown).

WIP: This engine has just started development and not really usable at this moment.

### Goals
The goal of this engine is to provide a very easy to use wrapper for window, 3D rendering, model loading, scene and object creation, UI and physics, with good defaults.

For example, this will init the engine, create a fullscreen window and run the update loop for you:

```zig
pub fn main() !void {
    var engine = try Engine.init(.{});
    defer engine.deinit();

    if (engine.isRunning()) {
        // do your stuff here
    }
}
```

### Using:
* [mach-glfw](https://machengine.org/pkg/mach-glfw/) for windowing
* [gl41](https://github.com/hexops/mach-glfw-opengl-example/blob/main/libs/gl41.zig) for OpenGL functions
* math from [mach](https://github.com/hexops/mach)
* [stb_image](https://github.com/nothings/stb/blob/master/stb_image.h) for texture loading

Made entirely on stream which you can catch on [twitch.tv/nothke](https://www.twitch.tv/nothke).

### How to build:
Simply run `zig build run`!