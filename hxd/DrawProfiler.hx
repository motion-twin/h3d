package hxd;
import h2d.Graphics;
import h2d.HtmlText;
import h2d.Interactive;
import h2d.Sprite;
import h2d.Text;
import h3d.Engine;
import hxd.res.FontBuilder;
import mt.gx.Proto;

enum ProfColor {
	Red;
	Orange;
	Green;
	PerfectGreen;
	Blue;
}

class DrawProfiler {

	public static var TIP_FG_COL = 0x0;
	public static var BG = 0x0;
	public static var TIP_SHADOW = true;

	public static inline function traverse(spr:h2d.Sprite,f:h2d.Sprite->Int->Void,depth:Int) {
		if( spr.visible ) {
			f(spr,depth);
			for (c in spr)
				traverse( c, f, depth+1);
		}
	}

	/**
	 * danger threshold for theses values:
	 *
	 * 								Desktop					Mobile
	 *
	 * _textureSwitches				30						10
	 * _shaderSwitches				100						30
	 * _drawTriangles				500k					100k
	 * _drawCalls					2000					500
	 * _renderTargetSwitch 			10						3
	 * _renderZoneSwitch			-						-
	 * _apiCalls					3000					800
	 * _memUsedMemory										<100Mo
	 * _memBufferCount				-						-
	 * _memAllocSize				-						-
	 * _memTexMemory				-						-
	 * _memTexCount					100						20
	 */
	public static function frameStats() {
		var eng = h3d.Engine.getCurrent();
		var mem = eng.mem;

		var res = {
			_textureSwitches	: eng.textureSwitches,
			_shaderSwitches		: eng.shaderSwitches,
			_drawTriangles		: eng.drawTriangles,
			_drawCalls			: eng.drawCalls,
			_renderTargetSwitch : eng.renderTargetSwitch,
			_renderZoneSwitch	: eng.renderZoneSwitch,
			_apiCalls			: eng.apiCalls,
			_memUsedMemory		: mem.usedMemory,
			_memBufferCount		: mem.bufferCount,
			_memAllocSize		: mem.allocSize,
			_memTexMemory		: mem.texMemory,
			_memTexCount		: mem.textureCount(),
		}

		return res;
	}

	public static function analyse(scene : h2d.Scene) {
		var collects : Array<Dynamic> = [];
		var id = 0;
		var curTex = null;
		var date = 0;

		traverse( scene, function(e, d) {
			var t :Dynamic = { };
			t.type = Type.getClass(e);
			t.id = id++;
			t.color = Blue;
			t.name = e.name;
			t.draw = 0;
			t.parent = e.parent;
			if ( Std.is(e, h2d.Drawable)) {
				var d = Std.instance( e, h2d.Drawable );
				#if flash
				t.shaderId = d.shader.getInstance().id;
				#else
				t.shaderId = d.shader.getSignature();
				#end

				t.blend = d.blendMode;

				if ( Std.is( d , h2d.Bitmap )) {
					var d  = Std.instance(d, h2d.Bitmap);
					t.tile = d.tile;
					t.tex = d.tile.getTexture();
					t.color = Red;
					t.draw++;
				}
				else
				if ( Std.is( d , h2d.Anim )) {
					var d  = Std.instance(d, h2d.Anim);
					t.tile = d.getFrame();
					t.tex = t.tile.getTexture();
					t.color = Red;
					t.draw ++;
				}
				else if ( Std.is( d , h2d.Mask )) {
					t.color = Orange;
				}
				else if ( Std.is( d , h2d.Graphics )) {
					var d  = Std.instance(d, h2d.Graphics);
					t.color = Orange;
					t.draw += d.nbQuad();
				}
				#if mt
				else if ( Std.is( d , mt.deepnight.slb.HSprite )) {
					var d = Std.instance(d, mt.deepnight.slb.HSprite);
					t.tile = d.tile;
					t.tex = d.tile.getTexture();
					t.color = Red;
					t.draw++;
				}
				#end
				else if ( Std.is( d , h2d.SpriteBatch )) {
					var d  = Std.instance(d, h2d.SpriteBatch  );
					t.tile = d.tile;
					t.tex = d.tile.getTexture();
					t.color = PerfectGreen;
					t.draw += d.nbQuad() ;
				}
				else if ( Std.is( d , h2d.Text )) {
					var d  = Std.instance(d, h2d.Text );
					var font = d.font;
					t.tile = font.tile;
					t.tex = font.tile.getTexture();
					t.color = Green;
					t.draw += d.nbQuad() ;
				}
				else if ( Std.is( d , h2d.HtmlText )) {
					var d  = Std.instance(d, h2d.HtmlText  );
					var font = d.font;
					t.tile = font.tile;
					t.tex = font.tile.getTexture();
					t.color = Green;
					t.draw += d.nbQuad() ;
				}
				else if ( Std.is( d , h2d.TileGroup )) {
					var d  = Std.instance(d, h2d.TileGroup  );
					t.tile = d.tile;
					t.tex = d.tile.getTexture();
					t.color = PerfectGreen;
					t.draw += d.count() ;
				}
				else if ( Std.is( d , h2d.TileColorGroup )) {
					var d  = Std.instance(d, h2d.TileColorGroup  );
					t.tile = d.tile;
					t.tex = d.tile.getTexture();
					t.color = PerfectGreen;
					t.draw += d.count();
				}
				else if ( Std.is( d , h2d.CachedBitmap )) {
					var d  = Std.instance(d, h2d.CachedBitmap);
					t.tile = d.tile;
					t.tex = d.tile.getTexture();
					t.color = Red;
					t.draw++;
				}
				t.exotic = d.isExoticShader();
			}
			t.date = date++;
			curTex = t.tex;
			t.depth = d;
			collects.push( t );
		},0);

		return collects;
	}

	static inline function colors( c:ProfColor) {
		return
		switch(c) {
			case Red:0xFF3C25;
			case Orange:0xFF7419;
			case Green:0x76B009;
			case PerfectGreen:0x00A406;
			case Blue:0x4349FF;
		}
	}

	public static function makeGfx( t : Array < Dynamic >, ?size=6 )  {
		var texPenaltyColor = 0xD449FF;
		var shaderPenaltyColor = 0x3DA6E8;
		var exoticPenaltyColor = 0xff0000;
		var font = FontBuilder.getFont("trebuchet", 10);

		var rt = new Sprite();
		var g = new h2d.Graphics(rt);

		var lst = new Sprite(rt);
		var legendTex = new h2d.Graphics(lst);
		legendTex.beginFill(texPenaltyColor);
		legendTex.drawRect(0, 2, 8, 4);
		legendTex.endFill();

		var txt = new h2d.Text(font, legendTex);
		txt.x = legendTex.width + 1;
		txt.text = "texPenalty";
		txt.textColor = TIP_FG_COL | (0xff << 24);

		if( TIP_SHADOW )
			txt.dropShadow = { dx:1, dy:1, color:0xffffff, alpha:1.0 };

		var legendShader = new h2d.Graphics(lst);
		legendShader.y = 10;
		legendShader.beginFill(shaderPenaltyColor);
		legendShader.drawRect(0, 2, 8, 4);
		legendShader.endFill();

		var txt = new h2d.Text(font, legendShader);
		txt.x = legendShader.width + 1;
		txt.text = "shaderPenalty";
		txt.textColor =  TIP_FG_COL | (0xff << 24);

		if( TIP_SHADOW )
			txt.dropShadow = { dx:1, dy:1, color:0xffffff, alpha:1.0 };

		var legendExotic = new h2d.Graphics(lst);
		legendExotic.y = 20;
		legendExotic.beginFill(exoticPenaltyColor);
		legendExotic.drawRect(0, 2, 8, 4);
		legendExotic.endFill();

		var txt = new h2d.Text(font, legendExotic);
		txt.x = legendExotic.width + 1;
		txt.text = "exoticPenalty";
		txt.textColor =  TIP_FG_COL | (0xff << 24);

		if( TIP_SHADOW )
			txt.dropShadow = { dx:1, dy:1, color:0xffffff, alpha:1.0 };

		var curX = 0.0;
		var curY = 50.0;
		var curTex = null;
		var curShader = null;
		var i = 0;
		for ( e in t ) {
			var inter = new h2d.Interactive(0, 0, g);
			var s = "";
			curX = e.depth * (size+4);

			inter.x = 0;
			inter.y = curY;

			//not same texture penalty
			//no tex penaly if its not a draw
			if ( curTex != e.tex && e.tile != null && e.draw > 0) {
				g.beginFill(texPenaltyColor);
				g.drawRect( 0, curY, curX+size, size);
				g.endFill();
				s += " texPenalty ";
				curY += size;
			}

			//not same texture penalty
			if ( curShader != e.shaderId && e.draw > 0) {
				g.beginFill(shaderPenaltyColor);
				g.drawRect( 0, curY, curX+size, size);
				g.endFill();
				s += " shaderPenalty ";
				curY += size;
			}

			//not same texture penalty
			if ( e.exotic == true && e.draw > 0) {
				g.beginFill(exoticPenaltyColor);
				g.drawRect( 0, curY, curX+size, size);
				g.endFill();

				s += " exotic ";
				curY += size;
			}

			var col = colors(e.color);
			g.beginFill(col);
			g.drawRect( curX, curY, size, size);
			g.endFill();

			curY += size;

			if ( e.name != null)
				s += " name:" + e.name;

			if ( e.type != null)
				s += " type:" + e.type;

			if ( e.draw != null && e.draw > 0 )
				s += " nb :" + e.draw;

			if( e.parent!=null )
				if( e.parent.name!=null )
					s += " parent:"+e.parent.name;
				else
					s += " parent:"+e.parent;

			inter.width = 60;
			inter.height = curY-inter.y;
			//inter.backgroundColor = mt.deepnight.Color.addAlphaF(0xFFFF00, 0.3);
			var t : h2d.Text = null;
			var over : h2d.Graphics = null;
			inter.onOver = function(_) {
				t = new h2d.Text( font, inter);
				t.name = "tip";
				t.x = inter.width + 10;
				t.textColor = TIP_FG_COL | (0xff << 24);

				if( TIP_SHADOW )
					t.dropShadow = { dx:1, dy:1, color:0xffffff, alpha:1.0 };
				t.text = s;

				over = new h2d.Graphics(inter);
				over.lineStyle(1, 0xFFFFFF, 1);
				over.drawRect(0,0,inter.width, inter.height);
			}
			inter.onOut = function(_) {
				if ( t != null) {
					t.dispose();
					t = null;
				}
				if ( over != null) {
					over.dispose();
					over = null;
				}
			}

			curTex = e.tex;
			curShader = e.shaderId;
			i++;
		}

		if ( BG != 0) {
			var bg = new h2d.Graphics(rt);
			bg.beginFill(BG&0xffffff, hxd.Math.b2f(BG >>> 24));
			bg.drawRect(0,0,rt.width,rt.height);
			bg.endFill();
			bg.toBack();
		}
		return rt;
	}
}