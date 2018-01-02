# View Soldat maps with LÖVE

```
git clone https://github.com/spxtr/os
cd os
love src
```

To open a specific map, point it at your Soldat installation:

```
love src /path/to/soldat/dir Map.pms
```

* [Soldat homepage](https://soldat.pl/)
* love2d [home](https://love2d.org/) and [docs](https://love2d.org/wiki/love)
* [PMS spec](https://wiki.soldat.pl/index.php/Map)
* [polyworks source](https://github.com/Soldat/polyworks) and [polybobin source](https://github.com/Soldat/polybobin) for reference

## TODO FIXME PLEASE

* Polygon edges.
* Look around with the mouse, zoom with the scrollwheel.
* View colliders, spawnpoints, and waypoints.
* Consider letterboxing instead of cutting off the edges. As currently
  implemented, a w/h ratio other than 4/3 is disadvantageous.
