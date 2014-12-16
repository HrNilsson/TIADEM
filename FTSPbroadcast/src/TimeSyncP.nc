/*
 * Copyright (c) 2002, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 *
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * @author: Miklos Maroti, Brano Kusy (kusy@isis.vanderbilt.edu), Janos Sallai
 * Ported to T2: 3/17/08 by Brano Kusy (branislav.kusy@gmail.com)
 */
#include "TimeSyncMsg.h"
#include "TestSerial.h"

generic module TimeSyncP(typedef precision_tag)
{
    provides
    {
        interface StdControl;
    }
    uses
    {
        interface Boot;
        interface SplitControl as RadioControl;
        interface TimeSyncAMSend<precision_tag,uint32_t> as Send;
        interface Receive;
        interface Timer<TMilli>;
        interface Leds;
        interface TimeSyncPacket<precision_tag,uint32_t>;
        interface SplitControl as SerialControl;
        interface Receive as PCReceive;
        interface AMSend as PCTransmit;
        interface Packet as PCPacket;
    }
}
implementation
{

    enum {
        BROADCAST_RATE 		  = 2,				// 30,
    };

    SyncReportMsg 	toPcBuffer; //buffer used for sending to pc
    SyncReportMsg* 	toPcPtr; //buffer pointer used for sending to pc

    message_t broadcastMsgBuffer;
    message_t toPcMsgBuffer;

 	uint16_t counter = 0;

    void task sendMsgToPC()
    {
    	call Leds.led0Toggle();
    	
    	atomic toPcPtr = (SyncReportMsg*)call Send.getPayload(&toPcMsgBuffer, sizeof(SyncReportMsg));
    	toPcPtr->nodeID = toPcBuffer.nodeID;
    	toPcPtr->globalTimeEst = toPcBuffer.globalTimeEst;
    	toPcPtr->syncPeriod = toPcBuffer.syncPeriod;
    	toPcPtr->drift = toPcBuffer.drift;
    	toPcPtr->temp = toPcBuffer.temp;
    	toPcPtr->seqNum = toPcBuffer.seqNum;

    	call PCTransmit.send(AM_BROADCAST_ADDR, &toPcMsgBuffer, sizeof(SyncReportMsg));
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
    	memcpy(&toPcBuffer,payload,sizeof(SyncReportMsg));
    	post sendMsgToPC();
    	return msg;
    }

    task void sendMsg()
    {
    	call Leds.led2Toggle();
    	
		call Send.send(AM_BROADCAST_ADDR, &broadcastMsgBuffer, 1, 0);
    }

    event void Send.sendDone(message_t* ptr, error_t error)
    {
        
    }

    event void Timer.fired()
    {	
    	// Ref broadcaster implementation
    	 post sendMsg();
    }
    
    event message_t* PCReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    	return bufPtr;
  	}

	event void PCTransmit.sendDone(message_t* bufPtr, error_t error) {
	}
  
	event void SerialControl.startDone(error_t error)
	{

	}
	
	event void SerialControl.stopDone(error_t error)
	{
	}

    event void Boot.booted()
    {
      //call Leds.led0On();
      call SerialControl.start();
      call RadioControl.start();
      call StdControl.start();
    }

    command error_t StdControl.start()
    {
        broadcastMsgBuffer.data[0] = 0xAA;        
        
        call Timer.startPeriodic((uint32_t)1000 * BROADCAST_RATE);

        return SUCCESS;
    }

    command error_t StdControl.stop()
    {
        call Timer.stop();
        return SUCCESS;
    }

    event void RadioControl.startDone(error_t error){}
    event void RadioControl.stopDone(error_t error){}
}
