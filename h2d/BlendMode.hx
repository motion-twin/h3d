package h2d;

enum BlendMode {
	/*
	 * Supported for Premul and Straight alpha
	 */
	Normal;		
	Add;
	
	/*Cannot be done with PreMul alpha in hardware if alpha channel is non one*/
	Multiply;
	
	None;
	SoftAdd;
	Erase;
}