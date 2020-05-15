package;

class Main
{
	/////////////////////////////////////////////////////////////////////////////////////
	

	static function main()
	{
		var serial = new Serial("COM8", 9600);
		if (serial.isSetup)
		{
			while (true)
			{
				if (serial.available() > 0)
				{
					var data:String = serial.readBytes(serial.available());
					serial.flush();
					
					trace(data);
				}
			}
		}		
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
}
