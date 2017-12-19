package hxd.snd;

@:allow(hxd.snd.Manager)
@:allow(hxd.snd.Driver)
@:allow(hxd.snd.ChannelBase)
class Effect {
	var kind    : Driver.EffectKind;
	var handle  : Driver.EffectHandle;
	var refs    : Int;

	@:noCompletion public var next : Effect;
	
	var allocated (get, never) : Bool;
	inline function get_allocated() return refs > 0;

	public function new(kind : Driver.EffectKind) { 
		this.kind = kind;
		this.refs = 0;
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