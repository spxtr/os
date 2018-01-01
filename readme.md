# View Soldat maps with LÖVE

```
git clone https://github.com/spxtr/os
cd os
love . /PATH/TO/SOLDAT/DIR [MAP.pms]
```

* [Soldat homepage](https://soldat.pl/)
* love2d [home](https://love2d.org/) and [docs](https://love2d.org/wiki/love)
* [PMS spec](https://wiki.soldat.pl/index.php/Map)
* [polyworks source](https://github.com/Soldat/polyworks) and [polybobin source](https://github.com/Soldat/polybobin) for reference

## TODO FIXME PLEASE

* Missing files currently halt the program.
  * Missing scenery should be replaced with a placeholder or nothing at all.
  * Missing textures should use a default.
* Make sure we're loading the appropriate version of files where we have both
  `.png` and `.bmp`.
* Some scenery are incorrectly scaled. It might be due to loading the wrong
  version. See the trees on the sides of `ctf_Ash` for an example.
* Look around with the mouse, zoom with the scrollwheel.
* View colliders, spawnpoints, and waypoints.
* Save screenshots.
* Control with command-line.
* Consider letterboxing instead of cutting off the edges. As currently
  implemented, a w/h ratio other than 4/3 is disadvantageous.
* Polygon edges.
