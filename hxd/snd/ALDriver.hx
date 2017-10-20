package hxd.snd;

#if hlopenal
typedef AL = openal.AL;
private typedef ALC          = openal.ALC;
private typedef ALDevice     = openal.ALC.Device;
private typedef ALContext    = openal.ALC.Context;
#else
typedef AL = hxd.snd.ALEmulator;
private typedef ALC       = hxd.snd.ALEmulator.ALCEmulator;
private typedef ALDevice  = hxd.snd.ALEmulator.ALDevice;
private typedef ALContext = hxd.snd.ALEmulator.ALContext;
#end
private typedef Source		= Driver.Source;
private typedef Buffer		= Driver.Buffer;
private typedef SourceID	= Driver.SourceID;
private typedef BufferID	= Driver.BufferID;

class OALSource extends Source {
	override public function updateCursorPosition(){
		super.updateCursorPosition();
		AL.sourcef(inst, AL.SEC_OFFSET, channel.position);
		channel.position = AL.getSourcef(inst, AL.SEC_OFFSET); // prevent rounding
		ALDriver.throwALError("updateCursorPosition");				
	}

	override public function getCursorPosition() : Float{ 
		return AL.getSourcef(inst, AL.SEC_OFFSET);
	}

	override public function play(){
		super.play();
		AL.sourcePlay(inst);
		ALDriver.throwALError("play");				
	}

	override public function stop(){
		if( playing ) {
			AL.sourceStop(inst);
			ALDriver.throwALError("stop");				
		}
		
		super.stop();		
	}

	override public function getState() : Int{
		var state = AL.getSourcei(inst, AL.SOURCE_STATE);
		if( state == AL.PLAYING ){
			return Source.STATE_PLAYING;
		}
		else if( state == AL.STOPPED ){
			return Source.STATE_STOPPED;
		}
		return Source.STATE_NONE;
	}

	override public function getProcessedBufferCount() : Int{
		return AL.getSourcei(inst, AL.BUFFERS_PROCESSED);
	}

	override public function setLooping(setting : Bool){
		super.setLooping(setting);
		AL.sourcei(inst, AL.LOOPING, setting ? AL.TRUE : AL.FALSE);
		ALDriver.throwALError("setLooping");				
	}

	override public function setVolume(v : Float){
		super.setVolume(v);
		AL.sourcef(inst, AL.GAIN, v);
		ALDriver.throwALError("setVolume");				
	}	

	override public function queueBuffers(buffersToQueue : Array<Buffer>){
		super.queueBuffers(buffers);

		var tmpBytes = Driver.getTmp(buffersToQueue.length * 4);
		for( i in 0...buffersToQueue.length ){
			tmpBytes.setInt32(i * 4, buffersToQueue[i].inst.toInt());
		}

		AL.sourceQueueBuffers(inst, buffersToQueue.length, tmpBytes);
		ALDriver.throwALError("queueBuffers");				
	}

	override public function unqueueBuffers(buffersToUnqueue : Array<Buffer>){
		var tmpBytes = Driver.getTmp(4 * buffersToUnqueue.length);
		for( i in 0...buffersToUnqueue.length )
			tmpBytes.setInt32(i << 2, buffersToUnqueue[i].inst.toInt());
		AL.sourceUnqueueBuffers(inst, buffersToUnqueue.length, tmpBytes);
		ALDriver.throwALError("unqueueBuffers");					
		
		super.unqueueBuffers(buffersToUnqueue);
	}

	override public function setBuffer(buffer : Buffer){
		AL.sourcei(inst, AL.BUFFER, buffer.inst.toInt());
		ALDriver.throwALError("setBuffer");				

		super.setBuffer(buffer);
	}

	override public function removeAllBuffers()	{
		if( !hasQueue ){
			ALDriver.throwALError("removeAllBuffers1");				
			AL.sourcei(inst, AL.BUFFER, AL.NONE);
			ALDriver.throwALError(" removeAllBuffers1bis " + inst.toInt());				
		}
		else {
			unqueueBuffers(buffers);
			ALDriver.throwALError("removeAllBuffers2");				
		}

		super.removeAllBuffers();
	}

	override function createBuffers(count : Int) : Array<Buffer>{
		var array = new Array<Buffer>();
		var alArray = OALBuffer.createALBuffers(count);
		for( i in 0 ... alArray.length){
			array.push(alArray[i]);
		}
		return array;
	} 
}

class OALBuffer extends Buffer {
	override function deleteBuffers(){
		var tmp = haxe.io.Bytes.alloc(4);
		tmp.setInt32(0, inst.toInt());
		AL.deleteBuffers(1, tmp);
		ALDriver.throwALError("deleteBuffers");				
	}

	public static function createALBuffers(count : Int) : Array<OALBuffer>{
		var tmpBytes = Driver.getTmp(4 * count);
		AL.genBuffers(count, tmpBytes);
		ALDriver.throwALError("createALBuffers");
		var array = new Array<OALBuffer>();
		for( i in 0 ... count){
			array.push(new OALBuffer(BufferID.ofInt(tmpBytes.getInt32(i * 4))));
		}
		return array;
	}

	public override function release(){
		super.release();

		var tmpBytes = Driver.getTmp(4);
		tmpBytes.setInt32(0, inst.toInt());
		AL.deleteBuffers(1, tmpBytes);
		ALDriver.throwALError("release");		
	}

	override public function setData(format : Int, dataBytes : haxe.io.Bytes, size : Int, samplingRate : Int){
		super.setData(format, dataBytes, size, samplingRate);
		AL.bufferData(inst, format, dataBytes, size, samplingRate);
		ALDriver.throwALError("setData");				
	}
}

class ALDriver extends Driver {

	// ------------------------------------------------------------------------
	// AL SHIT
	// ------------------------------------------------------------------------
	static inline var AL_NUM_SOURCES = 16;
	var alDevice      : ALDevice;
	var alContext     : ALContext;

	// ------------------------------------------------------------------------
	private function new() {
		super();
	}

	override function initLib(){
		// al init
		alDevice  = ALC.openDevice(null);
		alContext = ALC.createContext(alDevice, null);
		ALC.makeContextCurrent(alContext);
		ALC.loadExtensions(alDevice);
		AL.loadExtensions();
	 }

	public static function throwALError(where : String){
		var error = AL.getError();
		if( error != 0 ){
			 throw where + " " + error; 
		}		
	 }

	 override function createSources(){
		var bytes = haxe.io.Bytes.alloc(4);
		// alloc sources
		sources = [];
		for (i in 0...AL_NUM_SOURCES) {
			AL.genSources(1, bytes);
			if (AL.getError() != AL.NO_ERROR) break;
			var s = new OALSource(SourceID.ofInt(bytes.getInt32(0)), this);
			AL.sourcei(s.inst, AL.SOURCE_RELATIVE, AL.TRUE);
			if( s != null ){
				sources.push(s);
			}
		}
	}

	public function cleanCache() {
		for( b in buffers.copy() )
			if( b.playCount == 0 )
				releaseBuffer(b);
	}

	override function destroySources(){
		inline function arrayBytes(a:Array<Int>) {
			#if hlopenal
			return hl.Bytes.getArray(a);
			#else
			var b = haxe.io.Bytes.alloc(a.length * 4);
			for( i in 0...a.length )
				b.setInt32(i << 2, a[i]);
			return b;
			#end
		}
		AL.deleteSources(sources.length, arrayBytes([for( s in sources ) s.inst.toInt()]));
		throwALError("destroySources1");
		AL.deleteBuffers(buffers.length, arrayBytes([for( b in buffers ) b.inst.toInt()]));
		throwALError("destroySources2");		
	}

	override function releaseLib(){
		ALC.makeContextCurrent(null);
		ALC.destroyContext(alContext);
		ALC.closeDevice(alDevice);
	}

	public static function getInstance() : ALDriver{
		return cast(Driver.get(), ALDriver);
	}

	override function updateListenerParams(){
		AL.listenerf(AL.GAIN, masterVolume);
		throwALError("setListenerParams1");					
		
		AL.listener3f(AL.POSITION, -listener.position.x, listener.position.y, listener.position.z);
		throwALError("setListenerParams2");					
		
		listener.direction.normalize();
		var tmpBytes = Driver.getTmp(24);
		tmpBytes.setFloat(0,  -listener.direction.x);
		tmpBytes.setFloat(4,  listener.direction.y);
		tmpBytes.setFloat(8,  listener.direction.z);

		listener.up.normalize();
		tmpBytes.setFloat(12, -listener.up.x);
		tmpBytes.setFloat(16, listener.up.y);
		tmpBytes.setFloat(20, listener.up.z);

		AL.listenerfv(AL.ORIENTATION, tmpBytes);
		throwALError("setListenerParams3");	
	}				

	// ------------------------------------------------------------------------
	// internals
	// ------------------------------------------------------------------------
	override function createBuffers(count : Int) : Array<Buffer>{
		var array = new Array<Buffer>();
		var alArray = OALBuffer.createALBuffers(count);
		for( i in 0 ... alArray.length){
			array.push(alArray[i]);
		}
		return array;
	}


	override function checkTargetFormat( dat : hxd.snd.Data, forceMono = false ) {
		Source.targetRate = dat.samplingRate;
		#if !hl
		// perform resampling to nativechannel frequency
		Source.targetRate = AL.NATIVE_FREQ;
		#end
		Source.targetChannels = forceMono || dat.channels == 1 ? 1 : 2;
		Source.targetFormat = switch( dat.sampleFormat ) {
		case UI8:
			format = Source.targetChannels == 1 ? AL.FORMAT_MONO8 : AL.FORMAT_STEREO8;
			UI8;
		case I16:
			format = Source.targetChannels == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16;
			I16;
		case F32:
			#if hl
			format = Source.targetChannels == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16;
			I16;
			#else
			format = Source.targetChannels == 1 ? AL.FORMAT_MONOF32 : AL.FORMAT_STEREOF32;
			F32;
			#end
		}
		return Source.targetChannels == dat.channels && Source.targetFormat == dat.sampleFormat && Source.targetRate == dat.samplingRate;
	}
}