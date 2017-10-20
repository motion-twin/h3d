package hxd.snd;

#if hlopenal
typedef SourceID	= openal.AL.Source;
typedef BufferID	= openal.AL.Buffer;
#else
typedef SourceID	= hxd.snd.ALEmulator.ALSource;
typedef BufferID  	= hxd.snd.ALEmulator.ALBuffer;
#end


class Source{

	public static inline var STATE_NONE	= 0;
	public static inline var STATE_PLAYING = 1;
	public static inline var STATE_STOPPED = 2;

	public var channel : Channel;
	public var inst : SourceID;
	public var buffers : Array<Buffer>;

	public var loop = false;
	public var volume = 1.;
	public var playing = false;
	public var hasQueue = false;

	public var streamData : hxd.snd.Data;
	public var streamSample : Int;
	public var streamPosition : Float;
	public var streamPositionNext : Float;

	public static var targetChannels	: Int;
	public static var targetRate		: Int;
	public static var targetFormat		: Data.SampleFormat;
	static var resampleBytes 			: haxe.io.Bytes;
	
	
	var driver : Driver;
	public function new(inst : SourceID, driver : Driver) {
		this.inst = inst;
		this.driver = driver;
		buffers = [];
	}

	public function stop(){
		playing = false;
	}
	public function updateCursorPosition(){}
	public function getCursorPosition() : Float { 
		return 0; 
	}

	public function setLooping(setting : Bool){
		loop = setting;
	}

	public function setVolume(v : Float){
		volume = v;
	}

	public function getState() : Int{
		return STATE_NONE;
	}

	public function getProcessedBufferCount() : Int{
		return 0;
	}

	public function play(){
		playing = true;
	}

	public function beginStream(){
		hasQueue = true;
		buffers = createBuffers(2);
		streamData = channel.sound.getData();
		streamSample = Std.int(channel.position * streamData.samplingRate);
		// fill first two buffers
		updateStreaming(buffers[0], channel.soundGroup.mono);
		streamPosition = streamPositionNext;
		updateStreaming(buffers[1], channel.soundGroup.mono);
		queueBuffers(buffers);
	}

	public function updateStreaming(buf : Buffer, forceMono : Bool) {
		// decode
		var tmpBytes = Driver.getTmp(Driver.STREAM_BUFSIZE >> 1);
		var bpp = streamData.getBytesPerSample();
		var reqSamples = Std.int((Driver.STREAM_BUFSIZE >> 1) / bpp);
		var samples = reqSamples;
		var outPos = 0;
		var qPos = 0;

		while( samples > 0 ) {
			var avail = streamData.samples - streamSample;
			if( avail <= 0 ) {
				var next = @:privateAccess channel.queue[qPos++];
				if( next != null ) {
					streamSample -= streamData.samples;
					streamData = next.getData();
				} else if( !channel.loop || streamData.samples == 0 )
					break;
				else
					streamSample -= streamData.samples;
			} else {
				var count = samples < avail ? samples : avail;
				if( outPos == 0 )
					streamPositionNext = streamSample / streamData.samplingRate;
				streamData.decode(tmpBytes, outPos, streamSample, count);
				streamSample += count;
				outPos += count * bpp;
				samples -= count;
			}
		}

		if( !driver.checkTargetFormat(streamData, forceMono) ) {
			reqSamples -= samples;
			var bytes = resampleBytes;
			var reqBytes = targetChannels * reqSamples * Data.formatBytes(targetFormat);
			if( bytes == null || bytes.length < reqBytes ) {
				bytes = haxe.io.Bytes.alloc(reqBytes);
				resampleBytes = bytes;
			}
			streamData.resampleBuffer(resampleBytes, 0, tmpBytes, 0, targetRate, targetFormat, targetChannels, reqSamples);
			buf.setData(driver.format, resampleBytes, reqBytes, targetRate);
		} else {
			buf.setData(driver.format, tmpBytes, outPos, streamData.samplingRate);
		}
	}

	public function holdBuffers(buffer : Array<Buffer>){
		for( b in buffer ){
			b.playCount++;
			buffers.push(b);
		}
	}

	public function queueBuffers(buffer : Array<Buffer>){
	}

	public function unqueueBuffers(buffer : Array<Buffer>){
	}

	public function swapBuffers(){
		var b0 = buffers[0];
		var b1 = buffers[1];
		var tmp = Driver.getTmp(8);
		unqueueBuffers([b0]);				
		streamPosition = streamPositionNext;
		updateStreaming(b0, channel.soundGroup.mono);
		queueBuffers([b0]);
		buffers[0] = b1;
		buffers[1] = b0;
	}

	public function setBuffer(buffer : Buffer){
		if( buffers[0] != null ){
			buffers[0].unref();
		}
		buffers[0] = buffer;
		buffer.playCount++;
	}

	public function removeAllBuffers(){
		for( b in buffers )
			b.unref();

		buffers = [];
		streamData = null;
		hasQueue = false;
	}

	function createBuffers(count : Int) : Array<Buffer>{
		return null;
	}
}

class Buffer{
	public var inst : BufferID;
	public var sound : hxd.res.Sound;
	public var playCount : Int;
	public var lastStop : Float;

	function new(inst : BufferID) {
		this.inst = inst;
	}

	public function unref() {
		if( sound == null ) {
			deleteBuffers();
		} else {
			playCount--;
			if( playCount == 0 ) lastStop = haxe.Timer.stamp();
		}
	}

	function deleteBuffers(){}
	public function release(){
		@:privateAccess sound.data = null; // free cached decoded data
	}

	public function setData(format : Int, dataBytes : haxe.io.Bytes, size : Int, samplingRate : Int){
	}
}

class Driver{
	/**
		When a channel is streaming, how much data should be bufferize.
	**/
	public static var STREAM_BUFSIZE = 1 << 19;

	static var cachedBytes  : haxe.io.Bytes;
	public var masterVolume	: Float;
	public var masterSoundGroup   (default, null) : SoundGroup;
	public var masterChannelGroup (default, null) : ChannelGroup;
	public var listener : Listener;

	/**
		Automatically set the channel to streaming mode if its duration exceed this value.
	**/
	public static var STREAM_DURATION = 5.;

	var channels 			: Channel;
	var preUpdateCallbacks  : Array<Void->Void>;
	var postUpdateCallbacks : Array<Void->Void>;
	var sources       		: Array<Source>;
	var buffers       		: Array<Buffer>;
	var bufferMap     		: Map<hxd.res.Sound, Buffer>;
	public var format		: Int;

	static var instance : Driver;
	public static function get() : Driver {
		if( instance == null ) {
			#if psgl
			instance = @:privateAccess new ngs2.Ngs2Driver();
			#else
			instance = @:privateAccess new ALDriver();
			#end
			haxe.MainLoop.add(soundUpdate);
		}
		return instance;
	}

	public static function getTmp(size) {
		if( cachedBytes.length < size )
			cachedBytes = haxe.io.Bytes.alloc(size);
		return cachedBytes;
	}

	public function play(sound : hxd.res.Sound, ?channelGroup : ChannelGroup, ?soundGroup : SoundGroup) {
		if (soundGroup   == null) soundGroup   = masterSoundGroup;
		if (channelGroup == null) channelGroup = masterChannelGroup;
		var c = new Channel();
		c.driver = this;
		c.sound = sound;
		c.duration = c.sound.getData().duration;
		c.soundGroup   = soundGroup;
		c.channelGroup = channelGroup;
		c.next = channels;
		c.streaming = c.duration > STREAM_DURATION;
		channels = c;
		return c;
	}

	public function stopAll() {
		while( channels != null )
			channels.stop();
	}

	public function addPreUpdateCallback(f : Void->Void) {
		preUpdateCallbacks.push(f);
	}

	public function addPostUpdateCallback(f : Void->Void) {
		postUpdateCallbacks.push(f);
	}

	public function update() {
		// update playing channels from sources & release stopped channels
		var now = haxe.Timer.stamp();
		for( s in sources ) {
			var c = s.channel;
			if( c == null ) continue;
			var state = s.getState();
			switch (state) {
			case Source.STATE_STOPPED:
				if (c.streaming && s.streamPosition != s.streamPositionNext) {
					// force full resync
					releaseSource(s);
					continue;
				}
				releaseChannel(c);
				c.onEnd();
			case Source.STATE_PLAYING:
				if( c.streaming ) {
					if( c.positionChanged ) {
						// force full resync
						releaseSource(s);
						continue;
					}
					var count = s.getProcessedBufferCount();
					
					if( count > 0 ) {
						// swap buffers
						s.swapBuffers();
					}
					var position = s.getCursorPosition();
					var prev = c.position;
					c.position = position + s.streamPosition;
					c.lastStamp = now;
					if( c.position > c.duration ) {
						if( c.queue.length > 0 ) {
							s.streamPosition -= c.duration;
							queueNext(c);
							c.onEnd();
						} else if( c.loop ) {
							c.position -= c.duration;
							s.streamPosition -= c.duration;
							c.onEnd();
						}
					}
					c.positionChanged = false;
				} else if( !c.positionChanged ) {
					var position = s.getCursorPosition();
					var prev = c.position;
					c.position = position;
					c.lastStamp = now;
					c.positionChanged = false;
					if( c.queue.length > 0 ) {
						var count = s.getProcessedBufferCount();
						while( count > 0 ) {
							s.unqueueBuffers([s.buffers[0]]);
							queueNext(c);
							count--;
							c.onEnd();
						}
					} else if( position < prev )
						c.onEnd();
				}
			default:
			}
		}

		// calc audible gain & virtualize inaudible channels
		var c = channels;
		while (c != null) {
			c.calcAudibleGain(now);
			c.isVirtual = c.pause || c.mute || c.channelGroup.mute || c.audibleGain < 1e-5;
			c.soundGroup.numAudible = 0;
			c = c.next;
		}

		// sort channels by priority
		channels = haxe.ds.ListSort.sortSingleLinked(channels, sortChannel);

		{	// virtualize sounds that puts the put the audible count over the maximum number of sources
			var audibleCount = 0;
			var c = channels;
			while (c != null && !c.isVirtual) {
				if (++audibleCount > sources.length) c.isVirtual = true;
				else if (c.soundGroup.maxAudible >= 0 && ++c.soundGroup.numAudible > c.soundGroup.maxAudible) {
					c.isVirtual = true;
					--audibleCount;
				}
				c = c.next;
			}
		}

		// free sources that points to virtualized channels
		for ( s in sources ) {
			if ( s.channel == null || !s.channel.isVirtual) continue;
			releaseSource(s);
		}

		// update listener parameters
		updateListenerParams();
		
		// bind sources to non virtual channels
		var c = channels;
		while (c != null) {
			if( c.source != null || c.isVirtual ) {
				c = c.next;
				continue;
			}

			// look for a free source
			var s = null;
			for( s2 in sources )
				if( s2.channel == null ) {
					s = s2;
					break;
				}
			if( s == null ) throw "assert";
			s.channel = c;
			c.source = s;

			// bind buf and force full sync
			syncBuffers(s, c);
			c.positionChanged = true;
			c = c.next;
		}

		// update source parameters
		for ( s in sources ) {
			var c = s.channel;
			if( c == null) continue;
			syncSource(s);
		}
		
		var c = channels;
		while (c != null) {
			var next = c.next;
			// update virtual channels
			if (!c.pause && c.isVirtual) {
				c.position += now - c.lastStamp;
				c.lastStamp = now;
				if( c.position >= c.duration && !queueNext(c) && !c.loop ) {
					releaseChannel(c);
					c.onEnd();
				}
			}

			// clean removed effects
			if (c.channelGroup.removedEffects.length > 0) c.channelGroup.removedEffects = [];
			if (c.removedEffects != null && c.removedEffects.length > 0) c.removedEffects = [];
			c = next;
		}
	}	

	function sortChannel(a : Channel, b : Channel) {
		if (a.isVirtual != b.isVirtual)
			return a.isVirtual ? 1 : -1;

		if (a.channelGroup.priority != b.channelGroup.priority)
			return a.channelGroup.priority < b.channelGroup.priority ? 1 : -1;

		if (a.priority != b.priority)
			return a.priority < b.priority ? 1 : -1;

		if (a.audibleGain != b.audibleGain)
			return a.audibleGain < b.audibleGain ? 1 : -1;

		return a.id < b.id ? 1 : -1;
	}

	static function soundUpdate() {
		for (f in instance.preUpdateCallbacks) f();
		instance.update();
		for (f in instance.postUpdateCallbacks) f();
	}

	function new(){
		cachedBytes = haxe.io.Bytes.alloc(4 * 3 * 2);

		masterVolume       = 1.0;
		masterSoundGroup   = new SoundGroup  ("master");
		masterChannelGroup = new ChannelGroup("master");
		listener = new Listener();

		preUpdateCallbacks  = [];
		postUpdateCallbacks = [];

		buffers = [];
		bufferMap = new Map();

		initLib();
		createSources();
	}

	function initLib(){}
	function createSources(){}

	function dispose(){
		stopAll();

		destroySources();
		releaseLib();
		sources	= [];
		buffers	= [];
	}
	function destroySources(){}
	function releaseLib(){}

	function releaseChannel(c : Channel) {
		if (channels == c) {
			channels = c.next;
		} else {
			var prev = channels;
			while (prev.next != c)
				prev = prev.next;
			prev.next = c.next;
		}
		
		for (e in c.effects) c.removeEffect(e);
		if  (c.source != null) releaseSource(c.source);

		c.next = null;
		c.driver = null;
		c.removedEffects = null;
	}

	function releaseSource( s : Source ) {
		if (s.channel != null) {
			for (e in s.channel.channelGroup.removedEffects) e.unapply(s);
			for (e in s.channel.removedEffects) e.unapply(s);
			for (e in s.channel.channelGroup.effects) e.unapply(s);
			for (e in s.channel.effects) e.unapply(s);

			s.channel.source = null;
			s.channel = null;
		}
		s.stop();
		syncBuffers(s, null);
	}

	function syncBuffers( s : Source, c : Channel ) {
		if( c == null ) {
			if( s.buffers.length == 0 )
				return;
			s.removeAllBuffers();

		} else if( c.streaming ) {

			if( !s.hasQueue ) {
				if( s.buffers.length != 0 ) throw "assert";
				s.beginStream();
			}

		} else if( s.hasQueue || c.queue.length > 0 ) {

			if( !s.hasQueue && s.buffers.length > 0 )
				throw "Can't queue on a channel that is currently playing an unstreamed data";

			var locBuffers = [getBuffer(c.sound, c.soundGroup)];
			for( snd in c.queue )
				locBuffers.push(getBuffer(snd, c.soundGroup));

			// only append new ones
			for( i in 0...s.buffers.length )
				if( locBuffers.shift() != s.buffers[i] )
					throw "assert";

			s.queueBuffers(locBuffers);
			s.holdBuffers(locBuffers);
		} else {
			var buffer = getBuffer(c.sound, c.soundGroup);
			s.setBuffer(buffer);
		}
	}

	function createBuffers(count : Int) : Array<Buffer>{
		return null;
	}

	function getBuffer( snd : hxd.res.Sound, grp : SoundGroup ) : Buffer {
		var b = bufferMap.get(snd);
		if( b != null )
			return b;
		if( buffers.length >= 256 ) {
			// cleanup unused buffers
			var now = haxe.Timer.stamp();
			for( b in buffers.copy() ){
				if( b.playCount == 0 && b.lastStop < now - 60 ){
					releaseBuffer(b);
				}
			}
		}
		var b = createBuffers(1)[0];
		b.sound = snd;
		buffers.push(b);
		bufferMap.set(snd, b);
		var data = snd.getData();
		var mono = grp.mono;
		data.load(function() fillBuffer(b, data, mono));
		return b;
	}

	function releaseBuffer( b : Buffer ) {
		buffers.remove(b);
		bufferMap.remove(b.sound);
		b.release();
		b = null;
	}

	function updateListenerParams(){
	}

	function syncSource( source : Source ) {
		var c = source.channel;
		if( c == null ) return;
		if( c.positionChanged ) {
			if( !c.streaming ) {
				source.updateCursorPosition();
			}
			c.positionChanged = false;
		}
		var loopFlag = c.loop && c.queue.length == 0 && !c.streaming;
		if( source.loop != loopFlag ) {
			source.setLooping(loopFlag);
		}
		var v = c.currentVolume;
		if( source.volume != v ) {
			source.setVolume(v);
		}

		for (e in c.channelGroup.removedEffects) e.unapply(source);
		for (e in c.removedEffects) e.unapply(source);

		for (e in c.channelGroup.effects) e.apply(source);
		for (e in c.effects) e.apply(source);

		if( !source.playing ) {
			source.play();
		}
	}

	function queueNext( c : Channel ) {
		var snd = c.queue.shift();
		if( snd == null )
			return false;
		c.sound = snd;
		c.position -= c.duration;
		c.duration = snd.getData().duration;
		c.positionChanged = false;
		return true;
	}

	function fillBuffer(buf : Buffer, dat : hxd.snd.Data, forceMono = false) {
		if( !checkTargetFormat(dat, forceMono) )
			dat = dat.resample(Source.targetRate, Source.targetFormat, Source.targetChannels);
		var dataBytes = haxe.io.Bytes.alloc(dat.samples * dat.getBytesPerSample());
		dat.decode(dataBytes, 0, 0, dat.samples);
		buf.setData(format, dataBytes, dataBytes.length, dat.samplingRate);
	}

	public function checkTargetFormat( dat : hxd.snd.Data, forceMono = false ) {
		return true;
	}

}