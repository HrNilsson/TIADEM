/*									tab:4
 * "Copyright (c) 2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the following two paragraphs and the author appear in all
 * copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY
 * PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
 * DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
 * DOCUMENTATION, EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 */

/**
 * Java-side application for testing serial port communication.
 * 
 *
 * @author Phil Levis <pal@cs.berkeley.edu>
 * @date August 12 2005
 */

import java.io.*;
import java.util.*;
import java.text.*;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;



public class TestSerial implements MessageListener {

	/*private class SyncReportMsg {
		short	nodeID;			// the node if of the sender
		int	globalTimeEst;	// the senders estimation of the global time
		byte  syncPeriod;		// the senders synchronization period
		short  drift;			// the senders estimation of its child's drift
		short  temp;			// the senders temperature measurement
		byte	seqNum;		// sequence number for the root
	}*/

  private byte byteBuffer[];
	
  private MoteIF moteIF;
  
  private static File file;
  
  public TestSerial(MoteIF moteIF) {
    this.moteIF = moteIF;
    this.moteIF.registerListener(new TestSerialMsg(), this);
  }

  public void sendPackets() {
    int counter = 0;
    TestSerialMsg payload = new TestSerialMsg();
    
    try {
      while (true) {
	System.out.println("Sending packet " + counter);
	payload.set_counter(counter);
	moteIF.send(0, payload);
	counter++;
	try {Thread.sleep(1000);}
	catch (InterruptedException exception) {}
      }
    }
    catch (IOException exception) {
      System.err.println("Exception thrown when sending packets. Exiting.");
      System.err.println(exception);
    }
  }

  public void messageReceived(int to, Message message) {
	  byteBuffer = message.dataGet();

    try {
	  	  
	  	  String str = Arrays.toString(byteBuffer);

		  BufferedWriter out = new BufferedWriter(new FileWriter(file,true));
		  out.append(str);
		  out.newLine();
		  out.close();
		  System.out.println(str);
	  }
	  catch (Exception exception)
	  {
	      System.err.println("Exception thrown when instantiating the buffered writer or output string.");
	      System.err.println(exception);
	  }
    System.out.println("Received packet");
  }
  
  public static File createFile()
  {
	  Date date = new Date() ;
	  SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH-mm-ss") ;
	  File file = new File(dateFormat.format(date) + ".txt") ;
	  
	  return file;
  }
  
  public static void dumpReceivedMesssages(File file)
  {
	  
  }
  
  private static void usage() {
    System.err.println("usage: TestSerial [-comm <source>]");
  }
  
  public static void main(String[] args) throws Exception {
    String source = null;
    if (args.length == 2) {
      if (!args[0].equals("-comm")) {
	usage();
	System.exit(1);
      }
      source = args[1];
    }
    else if (args.length != 0) {
      usage();
      System.exit(1);
    }
    
    PhoenixSource phoenix;
    
    if (source == null) {
      phoenix = BuildSource.makePhoenix(PrintStreamMessenger.err);
    }
    else {
      phoenix = BuildSource.makePhoenix(source, PrintStreamMessenger.err);
    }
    
    file = createFile();

    MoteIF mif = new MoteIF(phoenix);
    TestSerial serial = new TestSerial(mif);
    //serial.sendPackets();
    while (true)
    {
    	
    }
  }


}
