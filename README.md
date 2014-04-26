Haxe 3D Engine
=========

A lightweight 3D Engine for Haxe.

Cross-platform Engine
-------------

h3d supports flash and openfl enabled target va GL (js is untested). This is the motion-twin branch, it has diverged from original but we plan to backmerge.

Among improvements : 
hw morph animations
better cpp memory access
improved 2d with bounds, skew, full TRS spriteBatch and filters.

This engine requires openfl to build & run feel free to contact us if need be !

In order to setup the engine, you can do :

> var engine = new h3d.Engine();
> engine.onReady = startMyApp;
> engine.init();

Then in your render loop you can do :

> engine.begin();
> ... render objects ...
> engine.end()

Objects can be created using a combination of a `h3d.mat.Material` (shader and blendmode) and `h3d.prim.Primitive` (geometry).

You can look at available examples in `samples` directory. The real_world example should give you every bit of hints you need.

2D GPU Engine
-------------

The `h2d` package contains classes that provides a complete 2D API that is built on top of `h3d`, and is then GPU accelerated.

It contains an object hierarchy which base class is `h2d.Sprite` and root is `h2d.Scene`

