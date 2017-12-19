package hxd.snd.effect;

// I3DL reverb

class Reverb extends Effect {
	public var room              : Float; // [-10000 0] mb
	public var roomHF            : Float; // [-10000, 0] mb
	public var roomRolloffFactor : Float; // [0.0, 1.0]
	public var decayTime         : Float; // [0.1, 20.0] s
	public var decayHFRatio      : Float; // [0.1, 2.0]
	public var reflections       : Float; // [-10000, 1000] mb
	public var reflectionsDelay  : Float; // [0.0, 0.3] s
	public var reverb            : Float; // [-10000, 2000] mb
	public var reverbDelay       : Float; // [0.0, 0.1] s
	public var diffusion         : Float; // [0.0, 100.0] %
	public var density           : Float; // [0.0, 100.0] %
	public var hfReference       : Float; // [20.0, 20000.0]

	public function new(?preset : ReverbPreset) {
		super(Reverb);
		loadPreset(preset != null ? preset : ReverbPreset.DEFAULT);
	}

	public function loadPreset(preset : ReverbPreset) {
		room             = preset.room;
		roomHF           = preset.roomHF;
		decayTime        = preset.decayTime;
		decayHFRatio     = preset.decayHFRatio;
		reflections      = preset.reflections;
		reflectionsDelay = preset.reflectionsDelay;
		reverb           = preset.reverb;
		reverbDelay      = preset.reverbDelay;
		diffusion        = preset.diffusion;
		density          = preset.density;
		hfReference      = preset.hfReference;
	}

	override function applyAudibleGainModifier(v : Float) {
		//return v + gain * Math.max(reflectionsGain, lateReverbGain);
		return v;
	}
}