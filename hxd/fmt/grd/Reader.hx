package hxd.fmt.grd;
import hxd.fmt.grd.Data;

class Reader {
	var i : haxe.io.Input;
	var version : Int;

	public function new(i) {
		this.i = i;
		i.bigEndian = true;
	}
	
	function readUnicode(input : haxe.io.Input, len : Int) : String {
		var res = "";
		for (i in 0...len - 1)  res += String.fromCharCode(input.readInt16());
		input.readInt16();
		return res;
	}
	
	function parseValue(i : haxe.io.Input) : Dynamic {
		var type = i.readString(4);
		var value : Dynamic;
		switch (type) {
			case "Objc" : value = parseObj (i);
            case "VlLs" : value = parseList(i);
            case "doub" : value = i.readDouble();
            case "UntF" : i.readString(4); value = i.readDouble();
            case "TEXT" : value = readUnicode(i, i.readInt32());
            case "enum" : value = parseEnum(i);
            case "long" : value = i.readInt32();
            case "bool" : value = i.readByte();
            case "tdtd" : var len = i.readInt32(); value = { length : len, value : i.read(len) };
			default     : throw "Unhandled type \"" + type + "\"";
		}
		return value;
	}
	
	function parseObj(i : haxe.io.Input) : Dynamic {
		var len  = i.readInt32(); if (len == 0) len = 4;
		var name = readUnicode(i, len);
		
		len = i.readInt32(); if (len == 0) len = 4;
		var type = i.readString(len);
		
		var obj = { name : name, type : type }
		
		var numProperties = i.readInt32();
		for (pi in 0...numProperties) {
			len = i.readInt32(); if (len == 0) len = 4;
			var key = i.readString(len);
			var si = key.indexOf(" ");
			if (si > 0) key = key.substring(0, si);
			Reflect.setField(obj, key, parseValue(i));
		}
		
		return obj;
	}
	
	function parseList(i : haxe.io.Input) {
		var res = new Array<Dynamic>();
		var len = i.readInt32();
		for (li in 0...len) 
			res.push(parseValue(i));
		return res;
	}
	
	function parseEnum(i : haxe.io.Input) {
		var len  = i.readInt32(); if (len == 0) len = 4;
		var type = i.readString(len);
		len = i.readInt32(); if (len == 0) len = 4;
		var value = i.readString(len);
		return { type : type, value : value };
	}
	
	public function read() : Data {
		var d = new Data();
		i.read(32); // skip header
		i.readString(4); // main object
		var list = cast(parseValue(i), Array<Dynamic>);
		for (obj in list) {
			var gradObj = obj.Grad;
			
			var name : String = gradObj.Nm;
			var colorStops = createColorStops(gradObj.Clrs);
			var transparencyStops = createTransparencyStops(gradObj.Trns);
			
			name = name.substring(name.indexOf("=") + 1);
			d.set(name, {
				name              : name,
				interpolation     : gradObj.Intr,
				colorStops        : colorStops,
				transparencyStops : transparencyStops,
				gradientStops     : createGradientStops(colorStops, transparencyStops)
			});
		}
		return d;
	}
	
	function createColorStops(list : Array<Dynamic>) : Array<ColorStop> {
		var a = new Array<ColorStop>();
		for (e in list) {
			var color = Color.RGB(0, 0, 0);
			var type  : ColorStopType;
			switch(e.Type.value) {
				case "UsrS" : type = USER;
				case "BckC" : type = BACKGROUND;
				case "FrgC" : type = FOREGROUND;
				default : throw "unhalndled color stop type : " + e.Type.value;
			}
			
			if (type == USER) {
				switch(e.Clr.type) {
					case "RGBC" : color = Color.RGB(e.Clr.Rd, e.Clr.Grn,  e.Clr.Bl);
					case "HSBC" : color = Color.HSB(e.Clr.H,  e.Clr.Strt, e.Clr.Brgh);
					default : //throw "unhandled color type : " + e.Clr.type;
				}
			}
			
			a.push({
				color    : color,
				location : e.Lctn,
				midpoint : e.Mdpn,
				type     : type
			});
		}
		return a;
	}
	
	function createTransparencyStops(list : Array<Dynamic>) : Array<TransparencyStop> {
		var a = new Array<TransparencyStop>();
		for (e in list) {
			a.push( {
				opacity  : e.Opct,
				location : e.Lctn,
				midpoint : e.Mdpn,
			});
		}
		return a;
	}
	
	function createGradientStops(colorStops : Array<ColorStop>, transparencyStops) : Array<GradientStop> {
		return colorStops.map(function(clr) {
			return { opacity : getOpacity(clr, transparencyStops), colorStop : clr };
		});
	}

	function getOpacity(clr : ColorStop, trns : Array<TransparencyStop>) {
		var index = -1;
		for (i in 0...trns.length) {
			var t = trns[i];
			if (t.location >= clr.location) {
				index = i;
				break;
			}
		}
		
		if (index == 0) return trns[0].opacity;
		if (index <  0) return trns[trns.length - 1].opacity;
		
		var prev = trns[index - 1];
		var next = trns[index];
		var w = next.location - prev.location;
		var h = next.opacity - prev.opacity;
		
		if (w == 0) return prev.opacity;
		var m = h / w;
		var b = prev.opacity - (m * prev.location);
		return m * clr.location + b;
	}
}
