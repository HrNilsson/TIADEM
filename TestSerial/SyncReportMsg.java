import java.io.*;
import net.tinyos.message.*;

public class SyncReportMsg extends Message {
	public long nodeID;
	public long timeEst;
	public long syncPeriod;
	public float drift;
	public float temp;
	public long seqNo;


	public SyncReportMsg(byte[] arr) {
		super(arr);
		long sign = 0;
		long exponent = 0;
		long mantissa = 0;

		nodeID = getUIntBEElement(0,2*8);
	    timeEst = getUIntBEElement(2*8,4*8);
	    syncPeriod = getUIntBEElement(6*8,1*8);
	    drift = Float.intBitsToFloat((int)getUIntBEElement(7*8,4*8));
	    temp = (float)(-39.6) + (float)(0.01*(float)getUIntBEElement(11*8,2*8));
	    seqNo = getUIntBEElement(13*8,1*8);
	}

	public String getString(){
		String str = "";

		str += Long.toString(nodeID) + " ";
		str += Long.toString(timeEst) + " ";
		str += Long.toString(syncPeriod) + " ";
		str += Float.toString(drift) + " ";
		str += Float.toString(temp) + " ";
		str += Long.toString(seqNo) + " ";
		str += Long.toString(System.currentTimeMillis());

		return str;
	}

}