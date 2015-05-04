package hxd;
import h2d.Graphics;
import h2d.HtmlText;
import h2d.Interactive;
import h2d.Sprite;
import h2d.Text;
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
		f(spr,depth);
		for (c in spr)
			traverse( c, f, depth+1);
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
				else if ( Std.is( d , mt.deepnight.slb.HSprite )) {
					var d = Std.instance(d, mt.deepnight.slb.HSprite);
					t.tile = d.tile;
					t.tex = d.tile.getTexture();
					t.color = Red;
					t.draw++;
				}
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
				else if ( Std.is( d , h2d.TextBatch )) {
					var d  = Std.instance(d, h2d.Text  );
					var font = d.font;
					t.tile = font.tile;
					t.color = PerfectGreen;
					t.tex = font.tile.getTexture();
					t.draw += d.nbQuad() ;
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
	
	public static function makeGfx( t : Array < Dynamic > )  {
		var texPenaltyColor = 0xD449FF;
		var shaderPenaltyColor = 0x3DA6E8;
		var exoticPenaltyColor = 0xff0000;
		var font = FontBuilder.getFont("trebuchet", 10);
		
		var rt = new Sprite();
		var g = new h2d.Graphics(rt);
		
		var lst = new Sprite(rt);
		var legendTex = new h2d.Graphics(lst);
		legendTex.beginFill(texPenaltyColor);
		legendTex.drawRect(0, 2, 8, 2);
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
		legendShader.drawRect(0, 2, 8, 2);
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
		legendExotic.drawRect(0, 2, 8, 2);
		legendExotic.endFill();
		
		var txt = new h2d.Text(font, legendExotic);
		txt.x = legendExotic.width + 1;
		txt.text = "exoticPenalty";
		txt.textColor =  TIP_FG_COL | (0xff << 24);
		
		if( TIP_SHADOW )
			txt.dropShadow = { dx:1, dy:1, color:0xffffff, alpha:1.0 };
		
		var curX = 0.0;
		var curY = 50.0;
		var size = 4.0;
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
				g.drawRect( 0, curY, curX+size, 2);
				g.endFill();
				s += " texPenalty ";
				curY += 2;
			}
			
			//not same texture penalty
			if ( curShader != e.shaderId && e.draw > 0) {
				g.beginFill(shaderPenaltyColor);
				g.drawRect( 0, curY, curX+size, 2);
				g.endFill();
				s += " shaderPenalty ";
				curY += 2;
			}
			
			//not same texture penalty
			if ( e.exotic == true && e.draw > 0) {
				g.beginFill(exoticPenaltyColor);
				g.drawRect( 0, curY, curX+size, 2);
				g.endFill();
				
				s += " exotic ";
				curY += 2;
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
				
			inter.width = curX + size;
			inter.height = curY - g.y;
			inter.onOver = function(_) {
				var t = new h2d.Text( font, inter);
				t.name = "tip";
				t.x = inter.width + 10;
				t.textColor = TIP_FG_COL | (0xff << 24);
				
				if( TIP_SHADOW )
					t.dropShadow = { dx:1, dy:1, color:0xffffff, alpha:1.0 };
				t.text = s;
			}
			inter.onOut = function(_) {
				var t = inter.findByName("tip");
				if ( t != null)
					t.remove();
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