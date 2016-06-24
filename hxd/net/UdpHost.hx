package hxd.net;
import hxd.net.NetworkHost;

typedef SafeChunk = {
	var idx : Int;
	var type : UdpType;
	var tick : Int;
	var bytes : haxe.io.Bytes;
};

typedef PacketData = {
	var id : Int;
	var tick : Int;
	var sent : Float;
	var changes : Map<Int,Int>;
	var safeChunks : Array<SafeChunk>;
};

@:enum
abstract UdpType(Int) {
	var SYNC            = 1;
	var REG             = 2;
	var UNREG           = 3;
	var FULLSYNC        = 4;
	var RPC             = 5;
	var RPC_WITH_RESULT = 6;
	var RPC_RESULT      = 7;
	var MSG	            = 8;
	var BMSG            = 9;
	var RPC_LAZY        = 10;

	var CONNECTED       = 0xFE;
	var HELLO           = 0xFF;
}


// TODO split big safe chunks
// TODO limit client caches

// Packet structure
// CRC     4  [crc32]
// GLOBAL  8  [packetId:16][fragment:8][lastAck:16][ackSeq:24]
// CHUNK   4+ [type:8][tick:16][len:Size]
// SYNC	   ([uid:32][len:Size]props*)*
// LAZY    [data...]
// SAFE    [id:16][data...]

class UdpClient extends NetworkClient {
	
	inline static var MAX_PACKET_SIZE = 1024;
	inline static var HEADSIZE = 8;
	
	public var ip : String;
	public var port : Int;
	
	// Sender
	var pktId : Int;
	var sentPackets : Map<Int,PacketData>;
	public var rtt(default,null) : Float;
	var tmpPropsChanges : Map<Int,Int>;
	var sBuffer : Array<{type: UdpType, tick: Int, bytes: haxe.io.Bytes}>;
	var sSafeBuffer : Array<SafeChunk>;
	var sSafeIndex : Int;
	
	var packetSent : Int;
	var packetLost : Int;
	
	// Receiver
	var newAck : Bool;
	var ack : Array<Int>;
	var rSafeIndex : Int;
	var rSafeBuffer : Map<Int,{type: UdpType, tick: Int, bytes: haxe.io.Bytes}>;
	var chunkBuffer : Map<Int,Array<{type: UdpType, bytes: haxe.io.Bytes}>>;
	var deferSync : Map<Int,Array<haxe.io.Bytes>>;
	var fragmentBuffer : Map<Int,Array<haxe.io.Bytes>>;
	
	public function new(host,ip:String=null,port:Int=0) {
		super(host);
		this.ip = ip;
		this.port = port;
		this.pktId = 0;
		this.newAck = false;
		this.ack = [];
		this.rtt = -1.0;
		this.packetSent = 0;
		this.packetLost = 0;
		this.sentPackets = new Map();
		this.sSafeBuffer = [];
		this.sSafeIndex = 0;
		this.sBuffer = [];
		this.rSafeBuffer = new Map();
		this.rSafeIndex = 0;
		this.deferSync = new Map();
		this.chunkBuffer = new Map();
		this.fragmentBuffer = new Map();
	}
	
	public function readData( buffer : haxe.io.Bytes, pos : Int ) {
		var input = new haxe.io.BytesInput(buffer);
		input.position = pos;
		
		var id = input.readUInt16();
		var fragment = input.readByte();
		
		if( fragment == 0 ){
			readChunk( id, input, buffer );
		}else{
			// Clean old incomplete fragmented packets
			for( i in fragmentBuffer.keys() ){
				if( i < id-70 )
					fragmentBuffer.remove(i);
			}
			
			var fNum = (fragment&0xF) + 1;
			var fId = fragment>>4;
			var b = fragmentBuffer.get(id);
			if( b == null )
				fragmentBuffer.set(id,b=[]);
			if( fId > 0 )
				input.position += 5;
			var f = haxe.io.Bytes.alloc(buffer.length-input.position);
			f.blit(0,buffer,input.position,f.length);
			b[fId] = f;
			if( b.length == fNum ){
				var size = 0;
				for( i in 0...fNum ) {
					if( b[i] == null ){
						size = -1;
						break;
					}
					size += b[i].length;
				}
				if( size > 0 ){
					fragmentBuffer.remove( id );
					var bytes = haxe.io.Bytes.alloc( size );
					var p = 0;
					for( i in 0...fNum ){
						var bi = b[i];
						bytes.blit(p,bi,0,bi.length);
						p += bi.length;
					}
					readChunk(id,new haxe.io.BytesInput(bytes),bytes);
				}
			}
		}
	}
	
	function readChunk( id : Int, input : haxe.io.BytesInput, buffer : haxe.io.Bytes ){
		// Ignore duplicate
		if( ack.indexOf(id) >= 0 )
			return;
		ack.push( id );
		newAck = true;
		
		var lastAck = input.readUInt16();
		var ackSeq = input.readUInt24();
		if( lastAck != 0 ){
			onAck( lastAck );
			for( i in 0...24 ){
				if( ackSeq & (1<<i) != 0 )
					onAck( lastAck - i );
			}
		}
		
		while( input.position < buffer.length ){
			var type : UdpType = cast input.readByte();
			var tick = seq16bit(input.readUInt16(), (cast host:UdpHost).tick);
			var size = input.readByte();
			if( size == 0xFF )
				size = input.readInt32();
			var p = input.position;
			var bytes = buffer.sub(p,size);
			input.position = p + size;
			
			var canProcessNow = type == HELLO || type == CONNECTED;
			if( canProcessNow || tick <= (cast host:UdpHost).tick ){
				processChunk( type, tick, bytes );
			}else{
				var o = {type: type, bytes: bytes};
				var a = chunkBuffer.get(tick);
				if( a == null )
					chunkBuffer.set( tick, [o] );
				else
					a.push( o );
			}
		}
	}

	@:allow(hxd.net.UdpHost)
	function syncTick( tick : Int ){
		var a = chunkBuffer.get( tick );
		if( a == null )
			return;
		chunkBuffer.remove( tick );
		for( o in a )
			processChunk( o.type, tick, o.bytes );
	}	
	
	function processChunk( type : UdpType, tick : Int, bytes : haxe.io.Bytes ){				
		switch( type ){
		case SYNC, RPC_LAZY:
			processChunkMessage(type,tick,bytes);
		case _:
			processSafeData( bytes.getUInt16(0), type, tick, bytes );
		}
	}

	function processSafeData( id : Int, type: UdpType, tick : Int, bytes : haxe.io.Bytes ){
		id = seq16bit(id,rSafeIndex);
		if( id == rSafeIndex ){
			processChunkMessage(type,tick,bytes,2);
			rSafeIndex++;
		}else if( id > rSafeIndex ){
			rSafeBuffer.set( id, { type: type, tick: tick, bytes: bytes } );
		}
		while( rSafeBuffer.exists(rSafeIndex) ){
			var s = rSafeBuffer.get(rSafeIndex);
			rSafeBuffer.remove(rSafeIndex);
			processChunkMessage(s.type,s.tick,s.bytes,2);
			rSafeIndex++;
		}
	}
	
	function processChunkMessage( type : UdpType, tick : Int, bytes : haxe.io.Bytes, ?pos : Int ) {
		if( pos == null ) pos = 0;
		var end = bytes.length;
		var ctx = host.ctx;
		ctx.setInput(bytes, pos);
		switch( type ) {
		case SYNC:
			ctx.tick = tick;
			while( @:privateAccess ctx.inPos < end ){
				var uid = ctx.getInt();
				var o : hxd.net.NetworkSerializable = cast ctx.refs[uid];
				var b = ctx.getBytes();
				if( o == null ){
					var a = deferSync.get(uid);
					if( a == null )
						deferSync.set(uid,[b]);
					else
						a.push(b);
				}else{
					syncObject(o,ctx,b);
				}
			}
			
		case REG:
			var o : hxd.net.NetworkSerializable = cast ctx.getAnyRef();
			host.makeAlive();
			var a = deferSync.get(o.__uid);
			if( a != null ){
				for( b in a )
					syncObject(o,ctx,b);
				deferSync.remove(o.__uid);
			}
		case UNREG:
			var o : hxd.net.NetworkSerializable = cast ctx.refs[ctx.getInt()];
			o.__lastChanges = null;
			o.__host = null;
			ctx.refs.remove(o.__uid);
			
		case FULLSYNC:
			ctx.refs = new Map();
			@:privateAccess {
				hxd.net.Serializer.UID = 0;
				hxd.net.Serializer.SEQ = ctx.getByte();
				ctx.newObjects = [];
			};
			while( true ) {
				var o = ctx.getAnyRef();
				if( o == null ) break;
			}
			host.makeAlive();
			for( k in deferSync.keys() ){
				var o : NetworkSerializable = cast ctx.refs[k];
				if( o == null ) continue;
				var a = deferSync.get(k);
				for( b in a )
					syncObject(o,ctx,b);
				deferSync.remove(k);
			}
			
		case RPC, RPC_LAZY:
			var o : hxd.net.NetworkSerializable = cast ctx.refs[ctx.getInt()];
			if( o != null ){
				var fid = ctx.getByte();
				if( !host.isAuth ) {
					var old = o.__host;
					o.__host = null;
					o.networkRPC(ctx, fid, this);
					o.__host = old;
				} else {
					host.rpcClientValue = this;
					o.networkRPC(ctx, fid, this);
					host.rpcClientValue = null;
				}
			}
			
		case RPC_WITH_RESULT:
			var old = resultID;
			resultID = ctx.getInt();
			var o : hxd.net.NetworkSerializable = cast ctx.refs[ctx.getInt()];
			var fid = ctx.getByte();
			if( !host.isAuth ) {
				var old = o.__host;
				o.__host = null;
				o.networkRPC(ctx, fid, this);
				o.__host = old;
			} else
				o.networkRPC(ctx, fid, this);
			sendChunk( RPC_RESULT, host.ctx.flush() );
			resultID = old;

		case RPC_RESULT:
			var resultID = ctx.getInt();
			var callb = host.rpcWaits.get(resultID);
			host.rpcWaits.remove(resultID);
			callb(ctx);

		case MSG:
			var msg = haxe.Unserializer.run(ctx.getString());
			host.onMessage(this, msg);

		case BMSG:
			var msg = ctx.getBytes();
			host.onMessage(this, msg);
			
		case HELLO:
			
		case CONNECTED:
			var tick = ctx.getInt32();
			(cast host:UdpHost).tick = tick - 2;
			
		case _:
			error("Unknown type");

		}
		return @:privateAccess ctx.inPos;
	}
	
	function syncObject( o : NetworkSerializable, ctx : Serializer, b : haxe.io.Bytes ){
		var oldP = @:privateAccess ctx.inPos;
		var oldBytes = @:privateAccess ctx.input;
		ctx.setInput(b,0);
		var old = o.__bits;
		var oldH = o.__host;
		o.__host = null;
		o.networkSync(ctx);
		o.__host = oldH;
		o.__bits = old;
		#if debug
		if( @:privateAccess ctx.inPos != b.length )
			throw "Error. Pos="+(@:privateAccess ctx.inPos)+" Expected="+b.length+" Data="+b.toHex();
		#end
		ctx.setInput(oldBytes,oldP);
	}
	
	//
	
	function onAck( pktId : Int ){
		var pkt = sentPackets.get( pktId );
		if( pkt == null )
			return;
		var tt = haxe.Timer.stamp() - pkt.sent;
		rtt = (rtt < 0) ? tt : (rtt * 9 + tt) * 0.1;
		sentPackets.remove( pktId );
	}
	
	override function beginRPCResult() {
		var ctx = host.ctx;
		ctx.addInt(resultID);
		// after that RPC will add result value then return
	}
		
	function getTmpPropsChanges() : Map<Int,Int> {
		if( tmpPropsChanges == null ){
			tmpPropsChanges = new Map();
			var cc = (cast host:UdpHost).curChanges;
			for( k in cc.keys() ) tmpPropsChanges.set(k,cc.get(k));
		}
		return tmpPropsChanges;
	}
	
	function checkPacketLost(){
		var maxTravelTime = rtt < 0 ? 1.0 : rtt * 3;
		var m = haxe.Timer.stamp() - maxTravelTime;
		for( p in sentPackets ){
			if( p.sent < m ){
				onPacketLost(p);
				sentPackets.remove(p.id);
			}
		}
	}
	
	function onPacketLost( pkt : PacketData ){
		packetLost++;
		var ctx = host.ctx;
		if( pkt.changes != null ){
			for( uid in pkt.changes.keys() ){
				var o : NetworkSerializable = cast ctx.refs[uid];
				var pbits = pkt.changes[uid];
				var nbits = 0;
				if( o == null ) continue;
				
				var i = 0;
				while( 1<<i <= pbits ){
					if( pbits & 1<<i != 0 && o.__lastChanges[i] <= pkt.tick )
						nbits |= 1<<i;
					i++;
				}
				
				if( nbits > 0 ){
					var curChanges = getTmpPropsChanges();
					var b = curChanges.get(uid);
					curChanges.set( uid, (b==null ? 0 : b) | nbits );
					
					var obits = o.__bits;
					o.__bits = nbits;
					ctx.addInt(o.__uid);
					var old = @:privateAccess ctx.out;
					@:privateAccess ctx.out = new haxe.io.BytesBuffer();
					o.networkFlush(ctx);
					var b = @:privateAccess ctx.out.getBytes();
					@:privateAccess ctx.out = old;
					ctx.addBytes(b);
					o.__bits = obits;
				}
			}
		}
		if( pkt.safeChunks != null ){
			for( c in pkt.safeChunks ){
				sSafeBuffer.push( c );
			}
		}
	}
	
	@:allow(hxd.net.UdpHost)
	function sendChunk( type: UdpType, bytes : haxe.io.Bytes ){
		switch( type ){
		case SYNC, RPC_LAZY:
			sBuffer.push({type: type, tick: (cast host:UdpHost).tick, bytes: bytes});
		case _:
			sSafeBuffer.push({idx: sSafeIndex++, type: type, tick: (cast host:UdpHost).tick, bytes: bytes});
		}
	}
	
	public function flush( syncPropsBytes : haxe.io.Bytes ){
		checkPacketLost();
		if( tmpPropsChanges != null ){
			var localSyncProps = host.ctx.flush();
			if( syncPropsBytes == null )
				syncPropsBytes = localSyncProps;
			else{
				var b = haxe.io.Bytes.alloc( syncPropsBytes.length + localSyncProps.length );
				b.blit(0,syncPropsBytes,0,syncPropsBytes.length);
				b.blit(syncPropsBytes.length,localSyncProps,0,localSyncProps.length);
				syncPropsBytes = b;
			}
		}
		
		if( sSafeBuffer.length == 0 && sBuffer.length == 0 && syncPropsBytes == null && !newAck )
			return;
		
		pktId++;
		if( pktId > 0xFFFF )
			pktId = 1;
		
		var h : UdpHost = cast host;
		var tick = h.tick;
		var curChanges;
		if( tmpPropsChanges == null ){
			curChanges = tmpPropsChanges;
			tmpPropsChanges = null;
		}else{
			curChanges = h.curChanges;
		}
		
		var safeChunks = null;
		if( sSafeBuffer.length > 0 ){
			safeChunks = sSafeBuffer;
			sSafeBuffer = [];
		}
		var chunks = null;
		if( sBuffer.length > 0 ){
			chunks = sBuffer;
			sBuffer = [];
		}
		
		sentPackets.set(pktId,{
			id: pktId,
			sent: haxe.Timer.stamp(),
			tick: tick,
			changes: curChanges,
			safeChunks: safeChunks,
		});
		
		var pk = new haxe.io.BytesOutput();
		var lastAck = 0;
		var ackSeq = 0;
		if( ack.length > 0 ){
			for( v in ack ) if( v > lastAck ) lastAck = v;
			
			var r = 0;
			for( v in ack ){
				if( v <= lastAck - 24 ){
					if( ackSeq == 0 )
						r++;
				}else{
					ackSeq |= 1<<(lastAck-v);
				}
			}
			if( r > 0 )
				ack.splice(0,r);
			newAck = false;
		}
		pk.writeUInt16(pktId);
		pk.writeByte(0); // fragment
		pk.writeUInt16(lastAck);
		pk.writeUInt24(ackSeq);
		
		inline function writeSize( size : Int ){
			if( size >= 0xFF ){
				pk.writeByte(0xFF);
				pk.writeInt32(size);
			}else
				pk.writeByte(size);
		}
		
		if( chunks != null ){
			for( c in chunks ){
				pk.writeByte(cast c.type);
				pk.writeUInt16(c.tick&0xFFFF);
				writeSize(c.bytes.length);
				pk.writeBytes(c.bytes, 0, c.bytes.length);
			}
		}
		if( safeChunks != null ){
			for( c in safeChunks ){
				pk.writeByte(cast c.type);
				pk.writeUInt16(c.tick&0xFFFF);
				writeSize(c.bytes.length+2);
				pk.writeUInt16(c.idx&0xFFFF);
				pk.writeBytes(c.bytes, 0, c.bytes.length);
			}
		}
		if( syncPropsBytes != null ){
			pk.writeByte( cast SYNC );
			pk.writeUInt16(tick&0xFFFF);
			writeSize( syncPropsBytes.length );
			pk.writeBytes(syncPropsBytes,0,syncPropsBytes.length);
		}
		
		var bytes = pk.getBytes();
		if( bytes.length > MAX_PACKET_SIZE ){
			var fragments = Math.ceil( (bytes.length-HEADSIZE) / (MAX_PACKET_SIZE-HEADSIZE) );
			if( fragments > 16 )
				throw "assert";
			packetSent++;
			for( i in 0...fragments ){
				var s = (i < fragments-1) ? MAX_PACKET_SIZE : (HEADSIZE + (bytes.length-HEADSIZE) % (MAX_PACKET_SIZE-HEADSIZE));
				var b = haxe.io.Bytes.alloc( s );
				b.blit( 0, bytes, 0, HEADSIZE);
				b.blit( HEADSIZE, bytes, HEADSIZE+i*(MAX_PACKET_SIZE-HEADSIZE), s-HEADSIZE );
				b.set(2, (i&0xF)<<4 | ((fragments-1)&0xF) );
				h.sendData(this,b);
			}
		}else{
			packetSent++;
			h.sendData(this,bytes);
		}
	}

	public function toString(){
		return "UdpClient("+ip+":"+port+")";
	}
	
	static function seq16bit( i : Int, max : Int ) : Int {
		var smax = max & 0xFFFF;
		var mmax = max >> 16;
		if( smax > 0xC000 && i < 0x4000 )
			mmax++;
		else if( smax < 0x4000 && i > 0xC000 )
			mmax--;
		return (mmax << 16) | i;
	}

}

class UdpHost extends NetworkHost {

	public var tick : Int;

	public var connected(default,null) = false;
	var onNewClient : UdpClient -> Void;
	var onConnect : Bool -> Void;
	var mClients : Map<String,UdpClient>;
	var socket : UdpSocket;
	
	@:allow(hxd.net.UdpClient)
	var curChanges : Map<Int,Int>;
	
	#if (debug || networkConditioner)
	public var packetLossRatio = 0.0;
	public var packetDelayMin = 0.0;
	public var packetDelayMax = 0.0;
	#end

	public function new() {
		super();
		isAuth = false;
		mClients = new Map();
		curChanges = new Map();
		tick = 0;
	}

	public function close() {
		if( socket != null ) {
			socket.close();
			socket = null;
		}
		connected = false;
		isAuth = false;
		self = null;
	}
	
	// TODO: Add timeout on connection and call onConnect(false)
	public function connect( host : String, port : Int, ?onConnect : Bool -> Void ) {
		close();
		
		socket = new UdpSocket();
		socket.bind("0.0.0.0", 0, onData);
		
		this.onConnect = onConnect;
		var c = new UdpClient(this,host,port);
		self = c;
		clients = [self];
		c.sendChunk( HELLO, haxe.io.Bytes.alloc(0) );
		c.flush(null);
	}

	public function wait( host : String, port : Int, ?onConnected : NetworkClient -> Void ) {
		close();
		
		this.onNewClient = onConnected;
		self = new UdpClient(this);
		isAuth = true;
		
		socket = new UdpSocket();
		socket.bind(host, port, onData);
	}
	
	@:allow(hxd.net.UdpClient)
	function sendData( client : UdpClient, data : haxe.io.Bytes ){
		totalSentBytes += data.length;
		inline function _send(){
			var packet = haxe.io.Bytes.alloc(data.length+4);
			packet.setInt32(0,0xdeadce11);
			packet.blit(4,data,0,data.length);
			packet.setInt32(0,haxe.crypto.Crc32.make(packet));
			socket.send( packet, client.ip, client.port );
		}
		
		#if (debug || networkConditioner)
		if( packetLossRatio > 0 && Math.random() < packetLossRatio )
			return;
		var delay = packetDelayMin + Math.random() * (packetDelayMax-packetDelayMin);
		if( delay > 0 )
			haxe.Timer.delay(function(){ _send(); },Std.int(delay*1000));
		else
		#end
		_send();
	}
	
	inline function debug( s : String ){
		#if debug
		trace(s);
		#end
	}
	
	function onData( data : haxe.io.Bytes, srcIP : String, srcPort : Int ){
		if( data.length < 12 ){
			debug("Incomplete packet: "+data.toHex());
			return;
		}
		
		var crc = data.getInt32(0);
		data.setInt32(0,0xdeadce11);
		if( crc != haxe.crypto.Crc32.make(data) ){
			debug("CRC mismatch");
			return;
		}
		
		var client : UdpClient;
		var ck = null;
		if( !isAuth && self != null ){
			client = cast self;
		}else{
			ck = srcIP+":"+srcPort;
			client = mClients.get( ck );
		}
		
		var firstType : UdpType = cast data.length>12 ? data.get(12) : -1;
		if( client == null && firstType != HELLO ){
			debug("Client must send HELLO packet first");
			return;
		}else if( !isAuth && !connected && firstType == CONNECTED ){
			connected = true;
			onConnect( true );
			onConnect = null;
		}
		
 		if( firstType == HELLO ){
			if( !isAuth ) return;
			if( client != null )
				client.stop();
			
			client = new UdpClient(this,srcIP,srcPort);
			mClients.set(ck,client);
			pendingClients.push( client );
			
			var b = haxe.io.Bytes.alloc(4);
			b.setInt32(0,tick);
			client.sendChunk( CONNECTED, b );
			
			onNewClient(client);
		}
		
		client.readData(data,4);
	}
	
	override function fullSync( c : NetworkClient ){
		if( !pendingClients.remove(c) )
			return;

		// unique client sequence number
		var seq = clients.length + 1;
		while( true ) {
			var found = false;
			for( c in clients )
				if( c.seqID == seq ) {
					found = true;
					break;
				}
			if( !found ) break;
			seq++;
		}
		c.seqID = seq;

		clients.push(c);
		var refs = ctx.refs;
		ctx.begin();
		ctx.addByte(c.seqID);
		for( o in refs )
			if( o != null )
				ctx.addAnyRef(o);
		ctx.addAnyRef(null);
		
		(cast c:UdpClient).sendChunk( FULLSYNC, ctx.flush() );
	}
	
	var curRPC : UdpType;
	override function beginRPC(o:NetworkSerializable, id:Int, onResult:Serializer->Void, lazy: Bool) {
		if( ctx.refs[o.__uid] == null )
			throw "Can't call RPC on an object not previously transferred";
			
		if( onResult != null ) {
			var id = rpcUID++;
			curRPC = RPC_WITH_RESULT;
			ctx.addInt(id);
			rpcWaits.set(id, onResult);
		} else
			curRPC = lazy ? RPC_LAZY : RPC;
		ctx.addInt(o.__uid);
		ctx.addByte(id);
		return ctx;
	}

	override function endRPC() {
		var b = ctx.flush();
		if( targetClient != null )
			(cast targetClient:UdpClient).sendChunk( curRPC, b );
		else
			for( c in clients )
				(cast c:UdpClient).sendChunk( curRPC, b );
	}
	
	override function sendMessage( msg : Dynamic, ?to : NetworkClient ) {
		var t;
		if( Std.is(msg, haxe.io.Bytes) ) {
			t = BMSG;
			ctx.addBytes(msg);
		} else {
			t = MSG;
			ctx.addString(haxe.Serializer.run(msg));
		}
		
		var b = ctx.flush();
		if( to == null )
			for( c in clients )
				(cast c:UdpClient).sendChunk( t, b );
		else
			(cast to:UdpClient).sendChunk( t, b );
	}
	
	override function makeAlive() {
		var objs = @:privateAccess ctx.newObjects;
		if( objs.length == 0 )
			return;
		while( true ) {
			var o = objs.shift();
			if( o == null ) break;
			var n = Std.instance(o, NetworkSerializable);
			if( n == null ) continue;
			n.__host = this;
			n.__lastChanges = new haxe.ds.Vector((untyped Type.getClass(o).__fcount));
			n.alive();
		}
		while( aliveEvents.length > 0 )
			aliveEvents.shift()();
	}
	
	override function register( o : NetworkSerializable ){
		if( ctx.refs[o.__uid] != null )
			return;
		if( !isAuth ) {
			var owner = o.networkGetOwner();
			if( owner == null || owner != self.ownerObject )
				throw "Can't register "+o+" without ownership (" + owner + " should be " + self.ownerObject + ")";
		}
		o.__host = this;
		o.__lastChanges = new haxe.ds.Vector((untyped Type.getClass(o).__fcount));
	
		unmark(o);
		ctx.addAnyRef(o);
		
		var b = ctx.flush();
		for( c in clients )
			(cast c:UdpClient).sendChunk( REG, b );
	}
	
	override function unregister( o : NetworkSerializable ){
		if( o.__host == null )
			return;
		if( !isAuth ) {
			var owner = o.networkGetOwner();
			if( owner == null || owner != self.ownerObject )
				throw "Can't unregister "+o+" without ownership (" + owner + " should be " + self.ownerObject + ")";
		}
		o.__host = null;
		o.__bits = 0;
		o.__lastChanges = null;
		unmark(o);
		
		ctx.refs.remove(o.__uid);
		ctx.addInt(o.__uid);
		var b = ctx.flush();
		for( c in clients )
			(cast c:UdpClient).sendChunk( UNREG, b );
	}
	
	override function flushProps(){
		var o = markHead;
		while( o != null ) {
			if( o.__bits != 0 ) {
				var b = curChanges.get(o.__uid);
				curChanges.set( o.__uid, (b==null ? 0 : b) | o.__bits );
				var i = 0;
				while( 1 << i <= o.__bits ) {
					if( o.__bits & (1 << i) != 0 )
						o.__lastChanges[i] = tick;
					i++;
				}
				
				ctx.addInt(o.__uid);
				var old = @:privateAccess ctx.out;
				@:privateAccess ctx.out = new haxe.io.BytesBuffer();
				o.networkFlush(ctx);
				var b = @:privateAccess ctx.out.getBytes();
				@:privateAccess ctx.out = old;
				ctx.addBytes(b);
				hasData = true;
			}
			var n = o.__next;
			o.__next = null;
			o = n;
		}
		markHead = null;
	}
	
	public function syncTick(){
		if( socket != null ) socket.read();
		for( c in clients )
			(cast c:UdpClient).syncTick( tick );
	}
	
	override function flush(){
		if( isAuth || connected ){
			flushProps();
		}
		var syncProps = hasData ? ctx.flush() : null;
		
		if( isAuth )
			for( c in mClients )
				c.flush( syncProps );
		else if( self != null )
			(cast self:UdpClient).flush( syncProps );
		
		curChanges = new Map();
		
		var now = haxe.Timer.stamp();
		var dt = now - lastSentTime;
		if( dt < 0.5 )
			return;
		var db = totalSentBytes - lastSentBytes;
		var rate = db / dt;
		sendRate = (sendRate + rate) * 0.5; // smooth
		lastSentTime = now;
		lastSentBytes = totalSentBytes;
	}
	
}

class UdpSocket {

	#if (flash && air3)
	var s : flash.net.DatagramSocket;
	var onData : haxe.io.Bytes -> String -> Int -> Void;
	
	public function new(){
	}
	
	public function close(){
		if( s != null ) {
			s.close();
			s = null;
			onData = null;
		}
	}
	
	public function bind( ip = "0.0.0.0", port = 0, onData : haxe.io.Bytes -> String -> Int -> Void ){
		close();
		this.onData = onData;
		s = new flash.net.DatagramSocket();
		s.bind(port, ip);
		s.addEventListener(flash.events.DatagramSocketDataEvent.DATA,onDataEvent);
		s.receive();
	}
	
	public function send( bytes : haxe.io.Bytes, ip : String, port : Int ){
		if( s == null )
			throw "UdpSocket not initialized";
		s.send( bytes.getData(), 0, bytes.length, ip, port );
	}
	
	function onDataEvent( event : flash.events.DatagramSocketDataEvent ){
		if( onData != null )
			onData( haxe.io.Bytes.ofData(event.data), event.srcAddress, event.srcPort );
	}
	
	public inline function read(){
	}
	
	#elseif sys
	
	var s : sys.net.UdpSocket;
	var buf : haxe.io.Bytes;
	var a : sys.net.Address;
	var onData : haxe.io.Bytes -> String -> Int -> Void;
	
	public function new(){
	}
	
	public function close(){
		if( s != null ) {
			s.close();
			s = null;
			onData = null;
		}
		a = null;
	}
	
	public function bind( ip = "0.0.0.0", port = 0, onData : haxe.io.Bytes -> String -> Int -> Void ){
		close();
		this.onData = onData;
		s = new sys.net.UdpSocket();
		s.setBlocking(false);
		s.bind(new sys.net.Host(ip), port);
		a = new sys.net.Address();
		buf = haxe.io.Bytes.alloc(1500);
	}
	
	public function send( bytes : haxe.io.Bytes, ip : String, port : Int ){
		if( s == null )
			throw "UdpSocket not initialized";
		
		a.host = new sys.net.Host(ip).ip;
		a.port = port;
		
		s.sendTo( bytes, 0, bytes.length, a );
	}
	
	public function read(){
		while( true ){
			try {
				var l = s.readFrom(buf,0,1500,a);
				onData(buf.sub(0,l), a.getHost().toString(), a.port);
			}catch( e : haxe.io.Error ){
				break;
			}
		}
	}
	
	#elseif hxnodejs
	
	var s : js.node.dgram.Socket;
	var onData : haxe.io.Bytes -> String -> Int -> Void;
	
	public function new(){
	}
	
	public function close(){
		if( s != null ) {
			s.close();
			s = null;
			onData = null;
		}
	}
	
	public function bind( ip = "0.0.0.0", port = 0, onData : haxe.io.Bytes -> String -> Int -> Void ){
		close();
		this.onData = onData;
		s = js.node.Dgram.createSocket({type: "udp4", reuseAddr: true},onDataEvent);
		s.bind(port,ip);
	}
	
	public function send( bytes : haxe.io.Bytes, ip : String, port : Int ){
		if( s == null )
			throw "UdpSocket not initialized";
		
		s.send(js.node.Buffer.hxFromBytes(bytes),0,bytes.length, port, ip);
	}
	
	function onDataEvent( buf : js.node.Buffer, addr : js.node.net.Socket.SocketAdress ){
		onData(buf.hxToBytes(), addr.address, addr.port);
	}
	
	public function read(){
	}
	
	#else
		#error "UdpSocket not implemented on current platform"
	#end
	
}