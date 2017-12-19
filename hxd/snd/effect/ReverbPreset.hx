package hxd.snd.effect;

class ReverbPreset {
	public var room              : Float;
	public var roomHF            : Float;
	public var roomRolloffFactor : Float;
	public var decayTime         : Float;
	public var decayHFRatio      : Float;
	public var reflections       : Float;
	public var reflectionsDelay  : Float;
	public var reverb            : Float;
	public var reverbDelay       : Float;
	public var diffusion         : Float;
	public var density           : Float;
	public var hfReference       : Float;

	public function new( 
		room              : Float,
		roomHF            : Float,
		roomRolloffFactor : Float,
		decayTime         : Float,
		decayHFRatio      : Float,
		reflections       : Float,
		reflectionsDelay  : Float,
		reverb            : Float,
		reverbDelay       : Float,
		diffusion         : Float,
		density           : Float,
		hfReference       : Float
	) {
		this.room              = room;
		this.roomHF            = roomHF;
		this.roomRolloffFactor = roomRolloffFactor;
		this.decayTime         = decayTime;
		this.decayHFRatio      = decayHFRatio;
		this.reflections       = reflections;
		this.reflectionsDelay  = reflectionsDelay;
		this.reverb            = reverb;
		this.reverbDelay       = reverbDelay;
		this.diffusion         = diffusion;
		this.density           = density;
		this.hfReference       = hfReference;
	}

	public static var DEFAULT         = new ReverbPreset(-1000, -100, 0.0, 1.49, 0.83, -2602, 0.007,   200, 0.011, 100.0, 100.0, 5000.0);
	public static var GENERIC         = new ReverbPreset(-1000, -100, 0.0, 1.49, 0.83, -2602, 0.007,   200, 0.011, 100.0, 100.0, 5000.0);
	public static var PADDEDCELL      = new ReverbPreset(-1000,-6000, 0.0, 0.17, 0.10, -1204, 0.001,   207, 0.002, 100.0, 100.0, 5000.0);
	public static var ROOM            = new ReverbPreset(-1000, -454, 0.0, 0.40, 0.83, -1646, 0.002,    53, 0.003, 100.0, 100.0, 5000.0);
	public static var BATHROOM        = new ReverbPreset(-1000,-1200, 0.0, 1.49, 0.54,  -370, 0.007,  1030, 0.011, 100.0,  60.0, 5000.0);
	public static var LIVINGROOM      = new ReverbPreset(-1000,-6000, 0.0, 0.50, 0.10, -1376, 0.003, -1104, 0.004, 100.0, 100.0, 5000.0);
	public static var STONEROOM       = new ReverbPreset(-1000, -300, 0.0, 2.31, 0.64,  -711, 0.012,    83, 0.017, 100.0, 100.0, 5000.0);
	public static var AUDITORIUM      = new ReverbPreset(-1000, -476, 0.0, 4.32, 0.59,  -789, 0.020,  -289, 0.030, 100.0, 100.0, 5000.0);
	public static var CONCERTHALL     = new ReverbPreset(-1000, -500, 0.0, 3.92, 0.70, -1230, 0.020,    -2, 0.029, 100.0, 100.0, 5000.0);
	public static var CAVE            = new ReverbPreset(-1000,    0, 0.0, 2.91, 1.30,  -602, 0.015,  -302, 0.022, 100.0, 100.0, 5000.0);
	public static var ARENA           = new ReverbPreset(-1000, -698, 0.0, 7.24, 0.33, -1166, 0.020,    16, 0.030, 100.0, 100.0, 5000.0);
	public static var HANGAR          = new ReverbPreset(-1000,-1000, 0.0,10.05, 0.23,  -602, 0.020,   198, 0.030, 100.0, 100.0, 5000.0);
	public static var CARPETEDHALLWAY = new ReverbPreset(-1000,-4000, 0.0, 0.30, 0.10, -1831, 0.002, -1630, 0.030, 100.0, 100.0, 5000.0);
	public static var HALLWAY         = new ReverbPreset(-1000, -300, 0.0, 1.49, 0.59, -1219, 0.007,   441, 0.011, 100.0, 100.0, 5000.0);
	public static var STONECORRIDOR   = new ReverbPreset(-1000, -237, 0.0, 2.70, 0.79, -1214, 0.013,   395, 0.020, 100.0, 100.0, 5000.0);
	public static var ALLEY           = new ReverbPreset(-1000, -270, 0.0, 1.49, 0.86, -1204, 0.007,    -4, 0.011, 100.0, 100.0, 5000.0);
	public static var FOREST          = new ReverbPreset(-1000,-3300, 0.0, 1.49, 0.54, -2560, 0.162,  -613, 0.088,  79.0, 100.0, 5000.0);
	public static var CITY            = new ReverbPreset(-1000, -800, 0.0, 1.49, 0.67, -2273, 0.007, -2217, 0.011,  50.0, 100.0, 5000.0);
	public static var MOUNTAINS       = new ReverbPreset(-1000,-2500, 0.0, 1.49, 0.21, -2780, 0.300, -2014, 0.100,  27.0, 100.0, 5000.0);
	public static var QUARRY          = new ReverbPreset(-1000,-1000, 0.0, 1.49, 0.83,-10000, 0.061,   500, 0.025, 100.0, 100.0, 5000.0);
	public static var PLAIN           = new ReverbPreset(-1000,-2000, 0.0, 1.49, 0.50, -2466, 0.179, -2514, 0.100,  21.0, 100.0, 5000.0);
	public static var PARKINGLOT      = new ReverbPreset(-1000,    0, 0.0, 1.65, 1.50, -1363, 0.008, -1153, 0.012, 100.0, 100.0, 5000.0);
	public static var SEWERPIPE       = new ReverbPreset(-1000,-1000, 0.0, 2.81, 0.14,   429, 0.014,   648, 0.021,  80.0,  60.0, 5000.0);
	public static var UNDERWATER      = new ReverbPreset(-1000,-4000, 0.0, 1.49, 0.10,  -449, 0.007,  1700, 0.011, 100.0, 100.0, 5000.0);
}