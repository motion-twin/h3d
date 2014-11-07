package h2d.comp;
import h2d.css.Defs;
import hxd.Assert;
import hxd.System;

class Component extends Sprite {
	
	public var id(default, set) : String;
	var parentComponent : Component;
	var classes : Array<String>;
	var components : Array<Component>;
	var iconBmp : h2d.Bitmap;
	
	var bgFill : h2d.css.Fill;
	var bgBmp : h2d.SpriteBatch;
	// the total width and height (includes margin,borders and padding)
	
	var contentWidth : Float = 0.;
	var contentHeight : Float = 0.;
	var style : h2d.css.Style;
	var customStyle : h2d.css.Style;
	var styleSheet : h2d.css.Engine;
	var needRebuild(default,set) : Bool;
	
	
	public override function set_width(w) 	return this.width=w;
	public override function set_height(h) 	return this.height=h;
	public override function get_width() 	return this.width;
	public override function get_height() 	return this.height;
	
	public function new(name,?parent) {
		super(parent);
		this.name = name;
		classes = [];
		components = [];
		if( parentComponent == null )
			while( parent != null ) {
				var p = Std.instance(parent, Component);
				if( p != null ) {
					parentComponent = p;
					p.components.push(this);
					break;
				}
				parent = parent.parent;
			}
			
		bgBmp = new h2d.SpriteBatch(h2d.Tile.fromColor(0xFFffffff),this);
		bgBmp.visible = false;
		bgFill = new h2d.css.Fill(this);
		
		needRebuild = true;
	}
	
	function getComponentsRec(s : Sprite, ret : Array<Component>) {
		var c = Std.instance(s, Component);
		if( c == null ) {
			for( s in s )
				getComponentsRec(s, ret);
		} else
			ret.push(c);
	}
	
	public function getParent() {
		if( allocated )
			return parentComponent;
		var c = parent;
		while( c != null ) {
			var cm = Std.instance(c, Component);
			if( cm != null ) return cm;
			c = c.parent;
		}
		return null;
	}
	
	public function getElementById(id:String) {
		if( this.id == id )
			return this;
		for( c in components ) {
			var c = c.getElementById(id);
			if( c != null )
				return c;
		}
		return null;
	}
	
	function set_needRebuild(v) {
		needRebuild = v;
		if( v && parentComponent != null && !parentComponent.needRebuild )
			parentComponent.needRebuild = true;
		return v;
	}
	
	override function onDelete() {
		if( parentComponent != null ) {
			parentComponent.components.remove(this);
			parentComponent = null;
		}
		super.onDelete();
	}
		
	override function onAlloc() {
		// lookup our parent component
		var old = parentComponent;
		var p = parent;
		while( p != null ) {
			var c = Std.instance(p, Component);
			if( c != null ) {
				parentComponent = c;
				if( old != c ) {
					if( old != null ) old.components.remove(this);
					c.components.push(this);
				}
				needRebuild = true;
				super.onAlloc();
				return;
			}
			p = p.parent;
		}
		if( old != null ) old.components.remove(this);
		parentComponent = null;
		super.onAlloc();
	}
	
	public function addCss(cssString) {
		if( styleSheet == null ) evalStyle();
		styleSheet.addRules(cssString);
		needRebuild = true;
	}
	
	public function setStyle(?s) {
		customStyle = s;
		needRebuild = true;
		return this;
	}
	
	public function getStyle( willWrite ) {
		if( customStyle == null )
			customStyle = new h2d.css.Style();
		if( willWrite )
			needRebuild = true;
		return customStyle;
	}

	public function addStyle(s) {
		if( customStyle == null )
			customStyle = new h2d.css.Style();
		customStyle.apply(s);
		needRebuild = true;
		return this;
	}

	public function addStyleString(s) {
		if( customStyle == null )
			customStyle = new h2d.css.Style();
		new h2d.css.Parser().parse(s, customStyle);
		needRebuild = true;
		return this;
	}
	
	public inline function getClasses() {
		return classes;
	}
	
	public function hasClass( name : String ) {
		return classes.indexOf( name ) >= 0;
	}
	
	public function addClass( name : String ) {
		if( ! hasClass( name) ) {
			classes.push(name);
			needRebuild = true;
		}
		return this;
	}
	
	public function toggleClass( name : String, ?flag : Null<Bool> ) {
		if( flag != null ) {
			if( flag )
				addClass(name)
			else
				removeClass(name);
		} else {
			if( !classes.remove(name) )
				classes.push(name);
			needRebuild = true;
		}
		return this;
	}
	
	public function removeClass( name : String ) {
		if( classes.remove(name) )
			needRebuild = true;
		return this;
	}
	
	function set_id(id) {
		this.id = id;
		needRebuild = true;
		return id;
	}
	
	function getFont() {
		return Context.getFont(style.fontName, Std.int(style.fontSize));
	}
	
	function evalStyle() {
		if( parentComponent == null ) {
			if( styleSheet == null )
				styleSheet = Context.getDefaultCss();
		} else {
			styleSheet = parentComponent.styleSheet;
			if( styleSheet == null ) {
				parentComponent.evalStyle();
				styleSheet = parentComponent.styleSheet;
			}
		}
		styleSheet.applyClasses(this);
	}
	
	inline function extLeft() {
		#if debug
		hxd.Assert.notNull(style.paddingLeft);
		hxd.Assert.notNull(style.marginLeft);
		hxd.Assert.notNull(style.borderSize);
		#end
		return style.paddingLeft + style.marginLeft + style.borderSize;
	}

	inline function extTop() {
		#if debug
		hxd.Assert.notNull(style.paddingTop);
		hxd.Assert.notNull(style.marginTop);
		hxd.Assert.notNull(style.borderSize);
		#end
		return style.paddingTop + style.marginTop + style.borderSize;
	}
	
	inline function extRight() {
		return style.paddingRight + style.marginRight + style.borderSize;
	}

	inline function extBottom() {
		return style.paddingBottom + style.marginBottom + style.borderSize;
	}
	
	var texMan:Map<String,{pixels:hxd.Pixels,tex:h3d.mat.Texture}>
	= new Map();
	
	function makeTile(t:TileStyle) : h2d.Tile {
		var d;
		if ( !texMan.exists(t.file) ) {
			d = { pixels:null, tex:null };
			switch(t.mode) {
				case Assets:
					#if openfl
					var path = t.file;
					var bmp = hxd.BitmapData.fromNative( openfl.Assets.getBitmapData( path, false ));
					var pixels = bmp.getPixels();
					var tex = h3d.mat.Texture.fromPixels(pixels);
					
					#if flash
					tex.flags.set( AlphaPremultiplied );
					#end
					
					tex.name = path;
					d.tex = tex;
					d.pixels = pixels;
					#end 
			}
			texMan.set( t.file, d );
		}
		d = texMan.get(t.file);
			
		return new h2d.Tile(d.tex,
			Math.round(t.x), Math.round(t.y), 
			Math.round(t.w), Math.round(t.h), Math.round(t.dx), Math.round(t.dy));
	}
	
	function makeBmp() {
		if ( style.backgroundTile == null) {
			bgBmp.visible = false;
			return;
		}
		
		var tile = style.backgroundTile;
		bgBmp.removeAllElements();
		bgBmp.tile = makeTile(tile);
		
		var curX = bgFill.x;
		var curY = bgFill.y;
				
		function repX() {
			var sz = bgBmp.tile.width;
			var nbUp = Math.ceil( width /sz);
			var nbDown = Math.floor( width / sz);
			var ltile = bgBmp.tile;
			
			for ( i in 0...nbUp ) {
				var lsz : Float = sz;
				if ( i == nbUp - 1 ) {
					if ( nbUp != nbDown ) {
						lsz = sz * ((width / sz) - nbDown);
						(ltile=ltile.clone()).setSize(Math.round(lsz),ltile.height);
					}
					else {
						break;
					}
				}
				
				var e = bgBmp.alloc(ltile);
				e.x = curX + i * sz;
				e.y = curY;
			}
		}
		
		function repY() {
			var sz = bgBmp.tile.height;
			var nbUp = Math.ceil( height / sz);
			var nbDown = Math.floor( height / sz);
			var ltile = bgBmp.tile;
			
			for ( i in 0...nbUp ) {
				var lsz : Float = sz;
				if ( i == nbUp - 1 ) {
					if ( nbUp != nbDown ) {
						lsz = sz * ((height / sz) - nbDown);
						(ltile=ltile.clone()).setSize(ltile.width,Math.round(lsz));
					}
					else {
						break;
					}
				}
				
				var e = bgBmp.alloc(ltile);
				e.x = curX;
				e.y = curY + i * sz;
			}
		}
		
		function repXY() {
			
			var szX = bgBmp.tile.width;
			var szY = bgBmp.tile.height;
			
			var nbHUp = Math.ceil( height / szY);
			var nbHDown = Math.floor( height / szY);
			
			var nbWUp = Math.ceil( width / szX);
			var nbWDown = Math.floor( width / szX);
			
			var ltile = bgBmp.tile;
			for ( y in 0...nbHUp ) {
				var yBreak = false;
				for ( x in 0...nbWUp ) {
						var lszX : Float = szX;
						var lszY : Float = szY;
						if ( x == nbWUp - 1 ) {
							if ( nbWUp != nbWDown ) {
								lszX = szX * ((width / szX) - nbWDown);
								(ltile=ltile.clone()).setSize(Math.round(lszX),ltile.height);
							}
							else 
								break;
						}
						
						if ( y == nbHUp - 1 ) {
							if ( nbHUp != nbHDown ) {
								lszY = szY * ((height / szY) - nbHDown);
								(ltile=ltile.clone()).setSize(ltile.width,Math.round(lszY));
							}
							else {
								yBreak = true;
							}
						}
						
						var e = bgBmp.alloc(ltile);
						e.x = curX + x * szX;
						e.y = curY + y * szY; 
				}
				ltile = bgBmp.tile;
				if ( yBreak )
					break;
			}
		}
		
		if( style.backgroundRepeat!=null)
		switch( style.backgroundRepeat ) {
			case RepeatX: 	repX();
			case RepeatY: 	repY();
			case Repeat:	repXY();
			default:
				var e = bgBmp.alloc(bgBmp.tile);
				e.x = bgFill.x;
				e.y = bgFill.y;
		}
		
		bgBmp.visible = true;
	}
	
	function resize( c : Context ) {
		if ( c.measure ) {
			if( style.width != null ) contentWidth = style.width;
			if( style.height != null ) contentHeight = style.height;
			width = contentWidth + extLeft() + extRight();
			height = contentHeight + extTop() + extBottom();
		} else {
			if ( style.positionAbsolute ) {
				var p = parent == null ? new h2d.col.Point() : parent.localToGlobal();
				x = style.offsetX + extLeft() - p.x;
				y = style.offsetY + extTop() - p.y;
			} else {
				if( c.xPos != null ) x = c.xPos + style.offsetX + extLeft();
				if( c.yPos != null ) y = c.yPos + style.offsetY + extTop();
			}

			bgFill.x = style.marginLeft - extLeft();
			bgFill.y = style.marginTop - extTop();
			
			if ( bgBmp != null) 
				makeBmp();

			if( bgFill != null){
				bgFill.setLine(	style.borderColor, 
					0, 0, width - (style.marginLeft + style.marginRight), height - (style.marginTop + style.marginBottom), style.borderSize);
				bgFill.setFill(	
					style.backgroundColor, style.borderSize, style.borderSize, 
					contentWidth + style.paddingLeft + style.paddingRight, contentHeight + style.paddingTop + style.paddingBottom);
				bgFill.softReset();
			}

			if( style.icon != null ) {
				if( iconBmp == null ) iconBmp = new h2d.Bitmap(null);
				bgFill.addChildAt(iconBmp, 0);
				iconBmp.x = extLeft() - style.paddingLeft + style.iconLeft;
				iconBmp.y = extTop() - style.paddingTop + style.iconTop;
				iconBmp.tile = Context.makeTileIcon(style.icon);
				iconBmp.colorKey = 0xFFFF00FF;
				if( iconBmp.color == null ) iconBmp.color = new h3d.Vector(1, 1, 1, 1);
				iconBmp.color.setColor(style.iconColor != null ? style.iconColor : 0xFFFFFFFF);
			} else if( iconBmp != null ) {
				iconBmp.remove();
				iconBmp = null;
			}
		}
	}
	
	function resizeRec( ctx : Context ) {
		resize(ctx);
		if( ctx.measure ) {
			for( c in components )
				c.resizeRec(ctx);
		} else {
			var oldx = ctx.xPos;
			var oldy = ctx.yPos;
			if( style.layout == Absolute ) {
				ctx.xPos = null;
				ctx.yPos = null;
			} else {
				ctx.xPos = 0;
				ctx.yPos = 0;
			}
			for( c in components )
				c.resizeRec(ctx);
			ctx.xPos = oldx;
			ctx.yPos = oldy;
		}
	}
	
	override function drawRec( ctx : h2d.RenderContext ) {
		var old : Null<h3d.Vector> = null;
		if ( style.overflowHidden ) {
			bgFill.afterDraw = function(){
				var px = (absX + 1) / matA + 1e-10;
				var py = (absY - 1) / matD + 1e-10;
				
				var rX = px;
				var rY = py;
				var rW = contentWidth;
				var rH = contentHeight;

				old = ctx.engine.getRenderZone();
				if ( old != null ){
					old = old.clone();

					rW = Math.min( rX+rW, old.x+old.z );
					rH = Math.min( rY+rH, old.y+old.w );
					rX = Math.max( rX, old.x );
					rY = Math.max( rY, old.y );

					rW -= rX;
					rH -= rY;
				}
				ctx.flush();
				ctx.engine.setRenderZone( Std.int(rX), Std.int(rY), Std.int(rW), Std.int(rH) );
			}
		}
		super.drawRec(ctx);
		if ( style.overflowHidden ) {
			ctx.flush();
			if( old == null )
				ctx.engine.setRenderZone();
			else
				ctx.engine.setRenderZone( Std.int(old.x), Std.int(old.y), Std.int(old.z), Std.int(old.w) );
		}
	}
	
	function evalStyleRec() {
		needRebuild = false;
		evalStyle();
		if( style.display != null )
			visible = style.display;
		else
			visible = true;
		for( c in components )
			c.evalStyleRec();
	}
	
	function textAlign( tf : h2d.Text ) {
		if( style.width == null ) {
			tf.x = 0;
			return;
		}
		switch( style.textAlign ) {
		case Left:
			tf.x = 0;
		case Right:
			tf.x = style.width - tf.textWidth;
		case Center:
			tf.x = Std.int((style.width - tf.textWidth) * 0.5);
		}
	}

	inline function textResize( tf : h2d.Text, text : String, ctx : Context ){
		tf.font = getFont();
		tf.textColor = style.color;
		tf.text = text;
		tf.filter = true;
		if( style.width != null ){
			tf.maxWidth = style.width;
		}else{
			tf.maxWidth = ctx.maxWidth;
		}
		contentWidth = tf.textWidth;
		contentHeight = tf.textHeight;
	}
	
	public function refresh() {
		needRebuild = true;
	}
	
	override function sync( ctx : RenderContext ) {
		if( needRebuild ) {
			evalStyleRec();
			var ctx = new Context(ctx.engine.width, ctx.engine.height);
			resizeRec(ctx);
			ctx.measure = false;
			resizeRec(ctx);
		}
		super.sync(ctx);
	}

	public function toString(){
		return '<$name'+(id!=null?' id="$id"':'')+(classes.length>0?' class="${classes.join(' ')}"':'')+'/>';
	}
	
}
