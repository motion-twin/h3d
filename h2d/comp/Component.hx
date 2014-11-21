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
		bgBmp.filter = true;
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
		var sz = Std.int(style.fontSize);
		h2d.css.Parser.fontResolver( style.fontName, sz);
		return Context.getFont(style.fontName, sz);
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
	
	
	function isContain() return style != null && style.backgroundSize != null && style.backgroundSize == Contain;
	function isCover() return style != null && style.backgroundSize != null && style.backgroundSize == Cover;
	
	function makeRepeat() {
		var tile = style.backgroundTile;
		bgBmp.removeAllElements();
		bgBmp.tile = Context.makeTile(tile);
		
		var curX = bgFill.x;
		var curY = bgFill.y;
				
		var width = this.width;
		var height = this.height;
		
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
				
				if ( isContain() ) 
					e.height = height;
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
				
				if ( isCover() ) 
					e.width = innerWidth();
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
				
		function dflt() {
			var e = bgBmp.alloc(bgBmp.tile);
			e.x = bgFill.x;
			e.y = bgFill.y;
			
			if( style.backgroundSize !=null ){
				switch(style.backgroundSize) {
					case Auto:
						if ( e.tile.width > width || e.tile.height > height) {
							var tile = e.tile = bgBmp.tile.clone();
							tile.setWidth(hxd.Math.imin( Std.int(innerWidth()), tile.width));
							tile.setHeight(hxd.Math.imin( Std.int(innerHeight()), tile.height));
						}
						
					case Cover:
						var tile = e.tile = bgBmp.tile.clone();
						var r = innerWidth() / tile.width;
						e.width = innerWidth();
						e.height = Std.int(tile.height * r);
						
					case Contain:
						var tile = e.tile = bgBmp.tile.clone();
						var r =  innerHeight() / tile.height;
						e.width = Std.int(tile.width * r);
						e.height = innerHeight();
					
					case Percent(px, py):
						e.width = innerWidth() * (px * 0.01);
						e.height = innerHeight() * (py * 0.01);
					
					default: trace("TODO");
				}
			}
		}
			
		if( style.backgroundRepeat!=null)
		switch( style.backgroundRepeat ) {
			case RepeatX: 	repX();
			case RepeatY: 	repY();
			case Repeat:	repXY();
			default:
				dflt();
		}
		else 
			dflt();
	}
	
	
	
	/**
	 * for 9 slice setup see : http://rwillustrator.blogspot.fr/2007/04/understanding-9-slice-scaling.html
	 */
	function makeBmp() {
		if ( style.backgroundColor != Transparent) {
			bgBmp.visible = false;
			return;
		}
		bgBmp.visible = true;
		
		if ( style.backgroundTile != null)
			makeRepeat();
		else if ( style.background9sliceTile != null) {
			var rect = style.background9sliceRect;
			var tile = style.background9sliceTile;
			
			bgBmp.removeAllElements();
			var ltile = (bgBmp.tile = Context.makeTile(tile));
		
			var curX = bgFill.x;
			var curY = bgFill.y;
			
			var left = Math.round( rect.left );
			var top = Math.round( rect.top );
			
			var right = Math.round( rect.right>=0?rect.right:ltile.width + rect.right);
			var bottom = Math.round( rect.bottom>=0?rect.bottom:ltile.height + rect.bottom);
			
			var tw = ltile.width;
			var th = ltile.height;
			
			/**
			 * TL T * TR
			 * 
			 * L C R
			 * 
			 * BL B  BR
			 */
			var tilesCoo = [
				ltile.sub( 0, 0, 		left, top ),			ltile.sub( left, 0, right - left, top ), 			ltile.sub( right, 0, 		tw-right, top ),
				ltile.sub( 0, top, 		left, bottom - top ),	ltile.sub( left, top, right - left, bottom - top ), ltile.sub( right, top, 		tw - right, bottom - top ),
				ltile.sub( 0, bottom, 	left, th-bottom ),		ltile.sub( left, bottom, right-left, th-bottom ), 	ltile.sub( right, bottom, 	tw-right, th-bottom ),
			];
			
			var tilesElem = tilesCoo.map(function(t) {
				var e = bgBmp.alloc(t);
				
				e.x = -100;
				
				return e;
			});
			
			//corners
			//top left
			tilesElem[0].x = curX;
			tilesElem[0].y = curY;
			
			//top right
			tilesElem[2].x = curX+width-tilesCoo[2].width;
			tilesElem[2].y = curY;
			
			//bottom left
			tilesElem[6].x = curX;
			tilesElem[6].y = curY+height-tilesCoo[6].height;
			
			//bottom right
			tilesElem[8].x = curX+width-tilesCoo[8].width;
			tilesElem[8].y = curY+height-tilesCoo[8].height;
			
			//bands 
			//up
			tilesElem[1].x = 		curX+tilesCoo[0].width;
			tilesElem[1].y = 		curY;
			tilesElem[1].width = 	tilesElem[2].x - tilesElem[0].x;
			
			//bottom
			tilesElem[7].x 		= 	tilesElem[1].x;
			tilesElem[7].y 		= 	tilesElem[6].y;
			tilesElem[7].width 	= 	tilesElem[1].width;
			
			//left
			tilesElem[3].x = 		tilesElem[0].x;
			tilesElem[3].y = 		tilesElem[0].y + tilesElem[0].height;
			tilesElem[3].height = 	tilesElem[6].y  - tilesElem[3].y;
			
			//right
			tilesElem[5].x = 		tilesElem[2].x;
			tilesElem[5].y = 		tilesElem[2].y + tilesElem[2].height;
			tilesElem[5].height = 	tilesElem[8].y  - tilesElem[2].y;
			
			///center
			tilesElem[4].x		= 	tilesElem[1].x;
			tilesElem[4].y		= 	tilesElem[3].y;
			tilesElem[4].width	= 	tilesElem[1].width;
			tilesElem[4].height = 	tilesElem[3].height;
		}
	}
	
	function getStyleHeight()  	return style.heightIsPercent ? parent.height * style.height : style.height;
	function getStyleWidth()  	return style.widthIsPercent ? parent.width * style.width : style.width;
	
	function innerWidth() {
		return width - (style.marginLeft + style.marginRight);
	}
	
	function innerHeight() {
		return height - (style.marginTop + style.marginBottom);
	}
	
	function resize( c : Context ) {
		if ( c.measure ) {
			if ( style.width != null ) 	contentWidth = getStyleWidth();
			if ( style.height != null ) contentHeight = getStyleHeight();
				
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
					0, 0, innerWidth(), innerHeight(), style.borderSize);
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
				var px = (absX + 1) / matA;
				var py = (absY - 1) / matD;
				
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
	
	function textVAlign( tf : h2d.Text ) {
		if( style.height == null ) {
			tf.y = 0;
			return;
		}
		
		switch( style.textVAlign ) {
		case Top:		tf.y = 0;
		case Bottom:	tf.y = Std.int(getStyleHeight() - tf.textHeight);
		case Middle:	tf.y = Std.int((getStyleHeight() - tf.textHeight) * 0.5);
		}
	}
	
	function textAlign( tf : h2d.Text ) {
		if( style.width == null ) {
			tf.x = 0;
			return;
		}
		switch( style.textAlign ) {
		case Left:	tf.x = 0;
		case Right:	tf.x = Std.int( getStyleWidth() - tf.textWidth);
		case Center:tf.x = Std.int((getStyleWidth() - tf.textWidth) * 0.5);
		}
	}
	
	inline function letterSpacing( tf : h2d.Text ) {
		if(style.letterSpacing!=null)
			tf.letterSpacing = style.letterSpacing;
	}

	function textColorTransform( tf : h2d.Text ) {
		if ( style.textColorTransform != null ) {
			var mat = new h3d.Matrix();
			mat.identity();
			
			var tmp = new h3d.Matrix();
			
			for ( c in style.textColorTransform ) {
				tmp.identity();
				if( c!=null)
				switch(c) {
					case Hue(v):			tmp.colorHue( v );
					case Saturation(v):		tmp.colorSaturation( v );
					case Brightness(v):		tmp.colorBrightness( v );
					case Contrast(v):		tmp.colorContrast( v );
				}
				mat.multiply( mat, tmp );
			}
			
			tf.colorMatrix = mat;
		}
	}
	
	inline function textResize( tf : h2d.Text, text : String, ctx : Context ){
		tf.font = getFont();
		tf.textColor = style.color;
		tf.text = text;
		tf.filter = true;
		if ( style.width != null ) 
			tf.maxWidth = style.widthIsPercent ? parent.width * style.width : style.width;
		else
			tf.maxWidth = ctx.maxWidth;
		
		contentWidth = tf.textWidth;
		contentHeight = tf.textHeight;
	}
	
	public function refreshGraphics() {
		makeBmp();
	}
	
	public function refresh() {
		needRebuild = true;
	}
	
	function syncExtra() {
		if ( 	style != null 
		&& 		style.backgroundTile != null 
		&& 		style.backgroundTile.update != null) 
			style.backgroundTile.update(this);
	}
	
	override function sync( ctx : RenderContext ) {
		syncExtra();
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

	function processText(tf:h2d.Text) {
		textAlign(tf);
		textVAlign(tf);
		textColorTransform(tf);
		letterSpacing(tf);
	}
}
