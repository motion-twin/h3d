package hxd.snd;

@:allow(hxd.snd.Manager)
@:allow(hxd.snd.Driver)
@:allow(hxd.snd.ChannelBase)
class Effect {
	var kind    : String;
	var params  : Dynamic;
	var handle  : Driver.EffectHandle;
	var refs    : Int;
	var changed : Bool;

	@:noCompletion public var next : Effect;
	
	var allocated (get, never) : Bool;
	inline function get_allocated() return refs > 0;

	public function new( kind : String, ?params : Dynamic ) { 
		this.kind    = kind;
		this.params  = params;
		this.refs    = 0;
		this.changed = true;
	}

	// used to evaluate gain midification for virtualization sorting
	public function applyAudibleGainModifier(v : Float) : Float {
		return v;
	}

	// used to tweak channel volume after virtualization sorting
	public function getVolumeModifier() : Float {
		return 1;
	}
	
}