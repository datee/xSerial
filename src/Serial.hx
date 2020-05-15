package ;
import cpp.Char;
import cpp.NativeString;
import cpp.UInt8;

/**
 * ...
 * @author Tommy S.
 * 
 */
//=======================================================================================
// Serial interface - C++ target / Win32 only
// Based on hxSerial https://github.com/andyli/hxSerial
//---------------------------------------------------------------------------------------	

////// Headers needed ///////////////////////////////////////////////////////////////////
 
@:cppFileCode('
#pragma comment(lib, "setupapi.lib")
#include <windows.h>
#include <setupapi.h>
')
class Serial 
{
	// Properties ///////////////////////////////////////////////////////////////////////

	public var portName(default,null)	: String;
	public var baud(default,null)		: Int;
	public var isSetup					: Bool;
	public var availableDevices			: Array<ComDevice>;
	
	var hnd								: Int;
		
	//===================================================================================
	// Creation
	//-----------------------------------------------------------------------------------	
	
	public function new(portName:String, ?baud:Int = 9600, ?setupImmediately:Bool = true)
	{
		isSetup = false;
		this.portName = portName;
		this.baud = baud;
		
		availableDevices = enumerateDevices();
		var bFoundDevice:Bool = false;
		for (d in availableDevices) 
		{
			if (d.portName == this.portName)
			{
				bFoundDevice = true;
				break;
			}
		}
		
		if (!bFoundDevice)
		{
			trace('Error setting up serial : Device $portName not found');
			return;
		}
		
		if (setupImmediately)
			setup();
	}	
	
	// Setup ////////////////////////////////////////////////////////////////////////////

	public function setup():Bool
	{
		var hComm:HANDLE = untyped __cpp__('CreateFile(portName,GENERIC_READ|GENERIC_WRITE,0,NULL,OPEN_EXISTING,0,NULL)');
		if(hComm==untyped INVALID_HANDLE_VALUE)
			return false;
			
		var CommDCBCmd:String = 'baud=$baud parity=N data=8 stop=1';
		var h:Int = -1;
		var	cfgSize:DWORD=untyped 0;
		var cfg:COMMCONFIG;
		var	tOut:COMMTIMEOUTS;
		var	oldTimeout:COMMTIMEOUTS;
			
		cfgSize=untyped __cpp__('sizeof(cfg)');
		
		untyped __cpp__('GetCommConfig(hComm,&cfg,&cfgSize)');
		untyped __cpp__('SetCommState(hComm, &cfg.dcb)');//ret bool status
		untyped __cpp__('BuildCommDCBA(CommDCBCmd.c_str(), &cfg.dcb)');//MSC ver - ret bool status
		untyped __cpp__('SetCommState(hComm, &cfg.dcb)');//ret bool status
		untyped __cpp__('GetCommTimeouts(hComm,&oldTimeout)');
		
		untyped __cpp__('tOut = oldTimeout');
		
		untyped __cpp__('tOut.ReadIntervalTimeout=MAXDWORD');
		untyped __cpp__('tOut.ReadTotalTimeoutMultiplier=0');
		untyped __cpp__('tOut.ReadTotalTimeoutConstant=0');
		untyped __cpp__('SetCommTimeouts(hComm,&tOut)');
		
		hnd = untyped __cpp__('(int)hComm');
		
		if (hnd != untyped INVALID_HANDLE_VALUE)
			isSetup = true;			
			
		return isSetup;
	}	
	
	//===================================================================================
	// Read
	//-----------------------------------------------------------------------------------	
	
	public function readBytes(length:Int):String
	{
		var str:String = "";
		var nRead:DWORD = untyped 0;		
		untyped __cpp__('
			char * buffer = (char*) malloc(length+1);
			ReadFile((HANDLE)hnd, buffer, length, & nRead, 0);
		');
		str = untyped __cpp__('reinterpret_cast<char const*>(buffer)');
		untyped __cpp__('free(buffer)');
		return str;
	}
	
	public function readByte():Null<Int>
	{
		var nRead:DWORD = untyped 0;
		var data:Null<Int> =null;
		untyped __cpp__('ReadFile((HANDLE)hnd, &data, 1, &nRead, 0)');
		return data;
	}

	//===================================================================================
	// Write
	//-----------------------------------------------------------------------------------	
	
	public function writeBytes(length:Int,data:String):Bool
	{
		var str:String = "";
		var written:DWORD=untyped 0;
		untyped __cpp__('unsigned char * buffer = (unsigned char*)data.c_str(); WriteFile((HANDLE)hnd, buffer, length, &written,0)');
		(cast written) > 0 ? return true : return false;
	}
	
	public function writeByte(data:Int):Bool
	{
		var written:DWORD=untyped 0;
		untyped __cpp__('
			unsigned char buffer = (unsigned char)data;
			WriteFile((HANDLE)hnd, &buffer, 1, &written, 0);
		');
		(cast written) > 0 ? return true : return false;
	}	
	
	//===================================================================================
	// Utils
	//-----------------------------------------------------------------------------------	
	
	public function available():Int
	{
		var numBytes:Int = 0;
		var err:DWORD = untyped 0;
		
		untyped __cpp__('COMSTAT stat');
		if (hnd != untyped __cpp__('(int)INVALID_HANDLE_VALUE'))
		{
			if (untyped __cpp__('!ClearCommError((HANDLE)hnd, &err, &stat)'))
				numBytes = 0;
			else
				numBytes = untyped __cpp__('stat.cbInQue');
		}
		return numBytes;
	}
	
	public function flush(?flushIn:Bool = false, ?flushOut = false)
	{
		var flushType:Int =-1;
		if (flushIn && flushOut)
			flushType = untyped PURGE_TXCLEAR | PURGE_RXCLEAR;
		else if (flushIn)
			flushType = untyped PURGE_RXCLEAR;
		else if (flushOut)
			flushType = untyped PURGE_TXCLEAR;
		else
			return;
			
		untyped __cpp__('PurgeComm((HANDLE)hnd, flushType)');
		return;
	}
	
	//===================================================================================
	// Enumeration
	//-----------------------------------------------------------------------------------	
	
	static public function enumerateDevices():Array<ComDevice>
	{
		var ports:Array<ComDevice> = [];
			
		var	hDevInfo:HDEVINFO = untyped NULL;
		var dataType:DWORD;
		var actualSize:DWORD;
		var	DeviceInterfaceData:SP_DEVINFO_DATA;
		untyped __cpp__('unsigned char dataBuf[MAX_PATH + 1]');

		hDevInfo = untyped __cpp__('SetupDiGetClassDevs((struct _GUID *)&GUID_SERENUM_BUS_ENUMERATOR,0,0,DIGCF_PRESENT)');
		if ( hDevInfo!=null )
		{
			for (i in 0...256) 
			{
				untyped __cpp__('ZeroMemory(&DeviceInterfaceData, sizeof(DeviceInterfaceData))');				
				untyped __cpp__('DeviceInterfaceData.cbSize = sizeof(DeviceInterfaceData)');			
				if (!untyped __cpp__('SetupDiEnumDeviceInfo(hDevInfo, i, &DeviceInterfaceData)'))
					break;

				if (untyped __cpp__('SetupDiGetDeviceRegistryProperty(hDevInfo, &DeviceInterfaceData, SPDRP_FRIENDLYNAME, &dataType, dataBuf, sizeof(dataBuf), &actualSize)'))
				{
					var portDescription:String = NativeString.fromPointer(untyped __cpp__('&dataBuf'));
					if (portDescription != null && portDescription.indexOf("COM")!=-1)
					{
						var pd = portDescription.split(")").join("").split("(");
						if (pd != null && pd.length==2)
							ports.push({type:pd[0],portName:pd[1],portNr:Std.parseInt(pd[1].split("COM").join(""))});
					}
				}
			}
		}
		untyped __cpp__('SetupDiDestroyDeviceInfoList(hDevInfo)');
		return ports;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////	
}
	// Types ////////////////////////////////////////////////////////////////////////////
	
	typedef ComDevice =
	{
		var type		: String;
		var portName	: String;
		var portNr		: Int;
	}

	@:native("HDEVINFO")		extern class HDEVINFO {}
	@:native("SP_DEVINFO_DATA")	extern class SP_DEVINFO_DATA {}
	@:native("DWORD")			extern class DWORD {}
	@:native("HANDLE")			extern class HANDLE {}
	@:native("COMMCONFIG")		extern class COMMCONFIG {}
	@:native("COMMTIMEOUTS")	extern class COMMTIMEOUTS {}
	
	/////////////////////////////////////////////////////////////////////////////////////