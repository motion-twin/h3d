package hxd.snd;

#if usesys
typedef SourceHandle = haxe.AudioTypes.SourceHandle;
typedef BufferHandle = haxe.AudioTypes.BufferHandle;
typedef EffectHandle = haxe.AudioTypes.EffectHandle;
#else
typedef SourceHandle = hxd.snd.openal.AudioTypes.SourceHandle;
typedef BufferHandle = hxd.snd.openal.AudioTypes.BufferHandle;
typedef EffectHandle = hxd.snd.openal.AudioTypes.EffectHandle;
#end

enum SourceState {
	Stopped;
	Playing;
	Unhandled;
}

interface Driver {
	public function setMasterVolume     (value : Float) : Void;
	public function setListenerParams   (position : h3d.Vector, direction : h3d.Vector, up : h3d.Vector, ?velocity : h3d.Vector) : Void;

	public function createSource        () : SourceHandle;
	public function setSourceBuffer     (source : SourceHandle, buffer : BufferHandle) : Void;
	public function removeSourceBuffer  (source : SourceHandle) : Void;
	public function playSource          (source : SourceHandle) : Void;
	public function stopSource          (source : SourceHandle) : Void;
	public function getSourceState      (source : SourceHandle) : SourceState;
	public function setSourcePosition   (source : SourceHandle, value : Float) : Void;
	public function setSourceVolume     (source : SourceHandle, value : Float) : Void;
	public function setSourceLooping    (source : SourceHandle, value : Bool) : Void;
	public function getSourcePosition   (source : SourceHandle) : Float;
	public function destroySource       (source : SourceHandle) : Void; 

	public function createBuffer        () : BufferHandle;
	public function setBufferData       (buffer : BufferHandle, data : haxe.io.Bytes, size : Int, format : Data.SampleFormat, channelCount : Int, samplingRate : Int) : Void;
	public function destroyBuffer       (buffer : BufferHandle) : Void;

	public function queueBuffer         (source : SourceHandle, buffer : BufferHandle) : Void;
	public function unqueueBuffer       (source : SourceHandle, buffer : BufferHandle) : Void;
	public function getProcessedBuffers (source : SourceHandle) : Int;

	public function update  () : Void;
	public function dispose () : Void;

	public function createEffect  (e : Effect) : Void;
	public function updateEffect  (e : Effect) : Void;
	public function destroyEffect (e : Effect) : Void;

	public function bindEffect    (e : Effect, source : SourceHandle) : Void;
	public function applyEffect   (e : Effect, source : SourceHandle) : Void;
	public function unbindEffect  (e : Effect, source : SourceHandle) : Void;
}