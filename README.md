# zigdown engine

A little OpenGL engine written in zig, inspired by my C++ engine used for [Shakedown Rally](https://nothke.itch.io/shakedown).

WIP: This engine is heavily under on-and-off development and not really usable at this moment.

Note that I left this project while I was in the middle of implementing glTF texture loading, hence why main.zig is full of unsuccessful glTF experiments. You're on your own fiddling with it.

Features progress:
- [x] Window handling
- [x] Input
- [x] Perspective projection camera
- [x] Meshes
- [x] Shaders
    - [x] Compiling
    - [x] Setting uniforms
- [x] Materials
    - [x] Properties
- [x] Transforms
- [x] Textures
- [x] Scene
- [x] (Game)Objects
- [ ] glTF loading - partial
- [ ] Primitives (submeshes)
- [ ] Removing Objects persistence
- [ ] Dear ImGui integration
- [ ] Physics
- [ ] Audio
- [ ] Arbitrary vertex layout meshes
- [ ] Skinned meshes
- [ ] Animations

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
Confirmed to build with Zig 0.13.0.

Simply run `zig build run`!