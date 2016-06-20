package hxd.net;
import hxd.net.NetworkHost;

typedef PacketData = {
	var id : Int;
	var tick : Int;
	var sent : Float;
	var changes : Map<Int,Int>;
};

class UdpClient extends NetworkClient {

	public var ip : String;
	public var port : Int;
	public var pktId : Int;
	public var sentPackets : Map<Int,PacketData>;
	public var ack : Array<Int>;
	public var rtt : Float;
	
	inline function h() : UdpHost return cast host;

	public function new(host,ip:String=null,port:Int=0) {
		super(host);
		this.ip = ip;
		this.port = port;
		this.pktId = 0;
		this.ack = [];
		this.rtt = -1.0;
		this.sentPackets = new Map();
	}
	
	function onAck( pktId : Int ){
		var pkt = sentPackets.get( pktId );
		if( pkt == null )
			return;
		var tt = haxe.Timer.stamp() - pkt.sent;
		rtt = (rtt < 0) ? tt : (rtt * 9 + tt) * 0.1;
		sentPackets.remove( pktId );
	}
	
	function onPacketLost( pkt : PacketData ){
		trace("Packet lost: "+pkt.id);
		var ctx = host.ctx;
		for( uid in pkt.changes.keys() ){
			var o : NetworkSerializable = cast ctx.refs[uid];
			var pbits = pkt.changes[uid];
			var nbits = 0;
			if( o == null ) continue;
			
			var i = 0;
			while( 1<<i <= pbits ){
				if( pbits & 1<<i != 0 && o.__lastChanges[i] == pkt.tick )
					nbits |= 1<<i;
				i++;
			}
			
			if( Std.is(o,Circle) ){
				trace("Circle#"+o.__uid+" pkt="+pkt.id+" PktTick="+pkt.tick+" bits: "+pbits+" => "+nbits+" lastChanges="+o.__lastChanges);
			}
			
			if( nbits > 0 ){
				// TODO add in packet changes
				if( Std.is(o,Circle) ) trace("resend: "+nbits+" for "+uid+"  ("+Type.getClassName(Type.getClass(o))+") to a client");
				var obits = o.__bits;
				o.__bits = nbits;
				ctx.addByte(NetworkHost.SYNC);
				ctx.addInt(o.__uid);
				o.networkFlush(ctx);
				if( host.checkEOM ) ctx.addByte(NetworkHost.EOM);
				o.__bits = obits;
			}
		}
	}

	public function readData( buffer : haxe.io.Bytes, pos : Int, len : Int ) {
		var id = buffer.getUInt16(pos);
		ack.push( id );
		
		var lastAck = buffer.getUInt16(pos+2);
		var ackSeq = buffer.getInt32(pos+4);
		var tick = buffer.getInt32(pos+8);
		pos += 12;
		if( lastAck != 0 ){
			onAck( lastAck );
			for( i in 0...32 ){
				if( ackSeq & (1<<i-1) != 0 )
					onAck( lastAck - i );
			}
		}
		
		var ctx = host.ctx;
		ctx.tick = tick;		
		//
		while( pos < len ) {
			var oldPos = pos;
			pos = processMessage(buffer, pos);
			if( host.checkEOM && buffer.get(pos++) != NetworkHost.EOM )
				throw "Message missing EOM " + buffer.sub(oldPos, pos - oldPos).toHex()+"..."+(buffer.sub(pos,hxd.Math.imin(len-pos,128)).toHex());
		}
	}
	
	// PacketId (16bit)
	// ACK ID: 16bit
	// ACK 32bit
	// TICK 32bit
	
	function checkPacketLost(){
		if( rtt < 0 ) return;
		var m = haxe.Timer.stamp() - rtt * 3;
		for( p in sentPackets ){
			if( p.sent < m ){
				onPacketLost(p);
				sentPackets.remove(p.id);
			}
		}
	}

	override function send( bytes : haxe.io.Bytes ) {
		@:privateAccess {
			var l = bytes.length;
			host.ctx.out.addBytes( bytes, 0, bytes.length );
			checkPacketLost();
			bytes = host.ctx.out.getBytes();
			if( bytes.length != l )
				trace("Add "+(bytes.length-l)+" bytes");
			host.ctx.out = new haxe.io.BytesBuffer();
		}
		
		pktId++;
		if( pktId > 0xFFFF )
			pktId = 1;
			
		sentPackets.set(pktId,{
			id: pktId,
			sent: haxe.Timer.stamp(),
			tick: h().tick,
			changes: h().curChanges,
		});
		
		for( uid in h().curChanges.keys() ){
			if( Std.is(host.ctx.refs[uid],Circle) && h().curChanges.get(uid)&4 != 0 )
				trace("Included in packet: "+pktId+" for Circle#"+uid);
		}
		
		//if( pktId % 30 == 0 )
		//	trace( rtt+" / "+sentPackets );
		
		var pk = haxe.io.Bytes.alloc(bytes.length+12);
		pk.setUInt16(0,pktId);
		var lastAck = 0;
		var ackSeq = 0;
		if( ack.length > 0 ){
			lastAck = ack[ack.length-1];
			var r = 0;
			for( i in 0...ack.length-1 ){
				var v = ack[i];
				if( v < lastAck - 32 )
					r++;
				else
					ackSeq |= 1<<(lastAck-v);
			}
			if( r > 0 )
				ack.splice(0,r);
		}
		pk.setUInt16(2,lastAck);
		pk.setInt32(4,ackSeq);
		pk.setInt32(8,h().tick);
		pk.blit(12,bytes,0,bytes.length);
		
		(cast host:UdpHost).sendData(this,pk);
	}

	public function toString(){
		return "UdpClient("+ip+":"+port+")";
	}

}



class UdpHost extends NetworkHost {
	
	public var tick : Int;

	var connected = false;
	var onNewClient : UdpClient -> Void;
	var mClients : Map<String,UdpClient>;
	#if (flash && air3)
	var socket : flash.net.DatagramSocket;
	#end
	
	@:allow(hxd.net.UdpClient)
	var curChanges : Map<Int,Int>;
	
	#if debug
	public var packetLossRatio = 0.0;
	#end

	public function new() {
		super();
		isAuth = false;
		mClients = new Map();
		curChanges = new Map();
		tick = 0;
	}

	public function close() {
		#if (flash && air3)
		if( socket != null ) {
			socket.close();
			socket = null;
		}
		#end
		connected = false;
		isAuth = false;
	}
	
	// TODO : manage pendingClients / clients / onConnect()
	public function connect( host : String, port : Int, ?onConnect : Bool -> Void ) {
		trace("connect("+port+")");
		#if (flash && air3)
		close();
		socket = new flash.net.DatagramSocket();
		self = new UdpClient(this,host,port);
		socket.bind(0, "0.0.0.0");
		socket.addEventListener(flash.events.DatagramSocketDataEvent.DATA,onSocketData);
		socket.receive();
		sendData(cast self,haxe.io.Bytes.alloc(0)); // TODO define this packet as a reliable packet (to enable auto ordering & retry on packet loss)
		connected = true;
		clients = [self];
		onConnect( true );
		#else
		throw "Not implemented";
		#end
	}

	public function wait( host : String, port : Int, ?onConnected : NetworkClient -> Void ) {
		close();
		#if (flash && air3)
		socket = new flash.net.DatagramSocket();
		self = new UdpClient(this);
		socket.bind(port, host);
		socket.addEventListener(flash.events.DatagramSocketDataEvent.DATA,onSocketData);
		this.onNewClient = onConnected;
		socket.receive();
		isAuth = true;
		#else
		throw "Not implemented";
		#end
	}
	
	@:allow(hxd.net.UdpClient)
	function sendData( client : UdpClient, data : haxe.io.Bytes ){
		#if debug
		if( packetLossRatio > 0 && Math.random() < packetLossRatio && client.pktId > 10 )
			return;
		#end
		var packet = haxe.io.Bytes.alloc(data.length+4);
		packet.setInt32(0,0xdeadce11);
		packet.blit(4,data,0,data.length);
		packet.setInt32(0,haxe.crypto.Crc32.make(packet));
		#if (flash && air3)
		socket.send( packet.getData(), 0, packet.length, client.ip, client.port );
		#end
	}
	
	#if (flash && air3)	
	function onSocketData( event : flash.events.DatagramSocketDataEvent ){
		onData( haxe.io.Bytes.ofData(event.data), event.srcAddress, event.srcPort );
	}
	#end
	
	function onData( data : haxe.io.Bytes, srcIP : String, srcPort : Int ){
		var crc = data.getInt32(0);
		data.setInt32(0,0xdeadce11);
		if( crc != haxe.crypto.Crc32.make(data) ){
			#if debug
			trace("CRC MISMATCH");
			#end
			return;
		}
		
		var client : UdpClient;
		var ck = null;
		if( connected && !isAuth ){
			client = cast self;
		}else{
			ck = srcIP+":"+srcPort;
			client = mClients.get( ck );
		}
		
		if( client == null && data.length > 4 ){
			#if debug
			trace("Client must send empty packet first");
			#end
			return;
		}
		
		
		if( data.length == 4 ){
			if( !isAuth ) return;
			if( client != null ){
				//client.close();
				clients.remove( client );
				pendingClients.remove( client );
			}
			client = new UdpClient(this,srcIP,srcPort);
			mClients.set(ck,client);
			pendingClients.push( client );
			onNewClient(client);
		}else{
			client.readData(data,4,data.length);
		}
	}
	
	
	override function register( o : NetworkSerializable ){
		o.__lastChanges = new haxe.ds.Vector((untyped Type.getClass(o).__fcount));
		super.register( o );
	}
	
	override function unregister( o : NetworkSerializable ){
		super.unregister(o);
		o.__lastChanges = null;
	}
	
	override function doSend(){
		super.doSend();
		curChanges = new Map();
	}
	
	override function flushProps(){
		ctx.tick = tick;
		var o = markHead;
		while( o != null ) {
			if( o.__bits != 0 ) {
				var b = curChanges.get(o.__uid);
				curChanges.set(o.__uid, b|o.__bits);
				if( logger != null ) {
					var props = [];
					var i = 0;
					while( 1 << i <= o.__bits ) {
						if( o.__bits & (1 << i) != 0 )
							props.push(o.networkGetName(i));
						i++;
					}
					logger("SYNC " + o + "#" + o.__uid + " " + props.join("|"));
				}
				ctx.addByte(NetworkHost.SYNC);
				ctx.addInt(o.__uid);
				o.networkFlush(ctx);
				if( checkEOM ) ctx.addByte(NetworkHost.EOM);
				hasData = true;
			}
			var n = o.__next;
			o.__next = null;
			o = n;
		}
		markHead = null;

	}
	
}