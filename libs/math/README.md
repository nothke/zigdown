This is [math](https://github.com/hexops/mach/tree/main/src/math) stripped from [mach](https://github.com/hexops/mach).

Changes:
- Removed references to `../main.zig`, which was only needed for getting `.math`, so I've replaced it with path includes
- Removed tests because they were referencing `mach.testing`
- Re-added projection matrix from old mach commit, even if it's wrong.. For now