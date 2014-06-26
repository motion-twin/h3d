package format.bson;

/**
 * @author Andre Lacasse
 * @author Matt Tuttle
 * @author Motion Twin
 */
class BSONDocument
{
	private var _nodes:List<BSONDocumentNode>;
	
	public function new() 
	{
		
		_nodes = new List<BSONDocumentNode>();
	}
	
	public static function create():BSONDocument
	{
		return new BSONDocument();
	}
	
	public function append(key:String, value:Dynamic):BSONDocument 
	{
		_nodes.add( new BSONDocumentNode( key, value ) ); 
		
		return this;
	}
	
	public function nodes():Iterator<BSONDocumentNode>
	{
		return _nodes.iterator();
	}
	
	public function toString():String
	{
		var iterator:Iterator<BSONDocumentNode> = _nodes.iterator();
		var s:StringBuf = new StringBuf();
		s.add( "{" );

		for ( node in iterator )
		{
			s.add( " " + node.key + " : " + node.data );
			
			if ( iterator.hasNext() ) s.add( "," );
		}
		
		s.add( "}" );
		
		return s.toString();
	}
	
}
