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

#ifdef DEBUG_WITH_PRINTF
	#include "printf.h"
#endif //DEBUG_WITH_PRINTF	

generic module TimeSyncP(typedef precision_tag)
{
    provides
    {
        interface Init;
        interface StdControl;
        interface GlobalTime<precision_tag>;

        //interfaces for extra functionality: need not to be wired
        interface TimeSyncInfo;
        interface TimeSyncMode;
        interface TimeSyncNotify;
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
        interface LocalTime<precision_tag> as LocalTime;
    }
}
implementation
{
    enum {
        MAX_ENTRIES           = 8,              // number of entries in the table
        MAX_CHILDREN		  = 5,				// Maximum number of children
        MAX_BEACON_INTERVAL   = 180,  			// Maximum time between sending the beacon msg (in seconds)
        MIN_BEACON_INTERVAL   = 10,  			// Minimum time between sending the beacon msg (in seconds)
        OFFSET_ERROR_BOUND	  = 62,				// Average offset error bound (in milliseconds) - 62ms ~ 2 ticks.
        ROOT_TIMEOUT          = 50,             // time to declare itself the root if no msg was received (in sync periods)
        IGNORE_ROOT_MSG       = 4,              // after becoming the root ignore other roots messages (in send period)
        ENTRY_VALID_LIMIT     = 4,              // number of entries to become synchronized
        ENTRY_SEND_LIMIT      = 3,              // number of entries to send sync messages
        ENTRY_THROWOUT_LIMIT  = 100,            // if time sync error is bigger than this clear the table
    };

    typedef struct TableItem
    {
        uint8_t     state;
        uint32_t    localTime;
        int32_t     timeOffset; // globalTime - localTime
    } TableItem;

    enum {
        ENTRY_EMPTY = 0,
        ENTRY_FULL = 1,
    };

    TableItem   table[MAX_ENTRIES];
    uint8_t tableEntries;

    enum {
        STATE_IDLE = 0x00,
        STATE_PROCESSING = 0x01,
        STATE_SENDING = 0x02,
        STATE_INIT = 0x04,
    };
    
    typedef struct ChildItem {
    	uint16_t nodeId;
    	float oldSkew;
    	uint32_t oldTime;
    	float drift;
    } ChildItem;

    uint8_t state, mode, beaconPeriod;
    ChildItem childTable[MAX_CHILDREN];
    uint8_t childEntries;
	float driftToTest;
/*
    We do linear regression from localTime to timeOffset (globalTime - localTime).
    This way we can keep the slope close to zero (ideally) and represent it
    as a float with high precision.

        timeOffset - offsetAverage = skew * (localTime - localAverage)
        timeOffset = offsetAverage + skew * (localTime - localAverage)
        globalTime = localTime + offsetAverage + skew * (localTime - localAverage)
*/

    float       skew;
    uint32_t    localAverage;
    int32_t     offsetAverage;
    uint8_t     numEntries; // the number of full entries in the table

    message_t processedMsgBuffer;
    message_t* processedMsg;

    message_t outgoingMsgBuffer;
    TimeSyncMsg* outgoingMsg;

    uint8_t heartBeats; // the number of sucessfully sent messages
                        // since adding a new entry with lower beacon id than ours

    async command uint32_t GlobalTime.getLocalTime()
    {
        return call LocalTime.get();
    }

    async command error_t GlobalTime.getGlobalTime(uint32_t *time)
    {
        *time = call GlobalTime.getLocalTime();
        return call GlobalTime.local2Global(time);
    }

    error_t is_synced()
    {
      if (numEntries>=ENTRY_VALID_LIMIT || outgoingMsg->rootID==TOS_NODE_ID)
        return SUCCESS;
      else
        return FAIL;
    }


    async command error_t GlobalTime.local2Global(uint32_t *time)
    {
        *time += offsetAverage + (int32_t)(skew * (int32_t)(*time - localAverage));
        return is_synced();
    }

    async command error_t GlobalTime.global2Local(uint32_t *time)
    {
        uint32_t approxLocalTime = *time - offsetAverage;
        *time = approxLocalTime - (int32_t)(skew * (int32_t)(approxLocalTime - localAverage));
        return is_synced();
    }
    
#ifndef DEBUG_WITH_PRINTF
	void printf(const char *format, ...) {}
	void printfflush(){}
#endif //DEBUG_WITH_PRINTF	
    
    void printfFloat(float toBePrinted) {
     uint32_t fi, f0, f1, f2;
     char c;
     float f = toBePrinted;

     if (f<0){
       c = '-'; f = -f;
     } else {
       c = ' ';
     }

     // integer portion.
     fi = (uint32_t) f;

     // decimal portion...get index for up to 3 decimal places.
     f = f - ((float) fi);
     f0 = f*10;   f0 %= 10;
     f1 = f*100;  f1 %= 10;
     f2 = f*1000; f2 %= 10;
     printf("%c%ld.%d%d%d", c, fi, (uint8_t) f0, (uint8_t) f1, (uint8_t) f2);
   }
    
    union f_and_u {
	  uint32_t u;
	  float f;
	};
    
    float u2f(uint32_t x)
	{
	  union f_and_u y = { .u = x};
	  return y.f;
	}
	
	uint32_t f2u(float x)
	{
	  union f_and_u y = { .f = x};
	  return y.u;
	}

    void calculateConversion()
    {
        float newSkew = skew;
        uint32_t newLocalAverage;
        int32_t newOffsetAverage;

        int64_t localSum;
        int64_t offsetSum;

        int8_t i;

        for(i = 0; i < MAX_ENTRIES && table[i].state != ENTRY_FULL; ++i)
            ;

        if( i >= MAX_ENTRIES )  // table is empty
            return;
/*
        We use a rough approximation first to avoid time overflow errors. The idea
        is that all times in the table should be relatively close to each other.
*/
        newLocalAverage = table[i].localTime;
        newOffsetAverage = table[i].timeOffset;

        localSum = 0;
        offsetSum = 0;

        while( ++i < MAX_ENTRIES )
            if( table[i].state == ENTRY_FULL ) {
                localSum += (int32_t)(table[i].localTime - newLocalAverage) / tableEntries;
                offsetSum += (int32_t)(table[i].timeOffset - newOffsetAverage) / tableEntries;
            }

        newLocalAverage += localSum;
        newOffsetAverage += offsetSum;

        localSum = offsetSum = 0;
        for(i = 0; i < MAX_ENTRIES; ++i)
            if( table[i].state == ENTRY_FULL ) {
                int32_t a = table[i].localTime - newLocalAverage;
                int32_t b = table[i].timeOffset - newOffsetAverage;

                localSum += (int64_t)a * a;
                offsetSum += (int64_t)a * b;
            }

        if( localSum != 0 )
            newSkew = (float)offsetSum / (float)localSum;

		printf("OffsetSum: %lld\n\r",offsetSum);
		printf("LocalSum: %lld\n\r",localSum);
		printf("NewSkew:");
		printfFloat(newSkew);
		printf(" offset float: ");
		printfFloat((float)offsetSum);
		printf(" local float: ");
		printfFloat((float)localSum);
		printf("\n\n\r");
		printfflush();
		
        atomic
        {
            skew = newSkew;
            offsetAverage = newOffsetAverage;
            localAverage = newLocalAverage;
            numEntries = tableEntries;
        }
        //printf("Skew: ");
        //printfFloat(skew);
        //printf("\n\roffsetAverage: %li\n\r",offsetAverage);
        //printf("localAverage: %lu\n\r",localAverage);
        //printf("numEntries: %u\n\r",numEntries);
        printfflush();
    }
	
    void updateBeaconPeriod(float maxDrift)
    {
    	float error = 0, tau = MIN_BEACON_INTERVAL;
    	float c = 10;
    	printf("MaxDrift: ");
    	printfFloat(maxDrift);
    	printf("\n\r");
    	if(maxDrift != 0)
    	{
    		while(error < OFFSET_ERROR_BOUND)
    		{
    			tau = tau + c;
    			error = maxDrift*((tau*tau)/2);
			}
			
			if(tau < MIN_BEACON_INTERVAL)
				tau = MIN_BEACON_INTERVAL;
			else if(tau > MAX_BEACON_INTERVAL)
				tau = MAX_BEACON_INTERVAL;
				
			atomic beaconPeriod = (unsigned char)(tau);
			printf("beacon period: %u\n\r", beaconPeriod);
    	}
    }
    
    void clearChildTable()
    {
    	uint8_t i;
    	for(i = 0; i < MAX_CHILDREN; i++) {
    		childTable[i].nodeId = 0xFFFF;
    		childTable[i].drift = 0;
		}
    	
    	atomic childEntries = 0;
    }
    
    void handleNewChildSkew(TimeSyncMsg *msg) {
    	uint8_t i, childExist = 0, sign = 1;
    	float maxDrift = 0;
		for(i = 0; i < childEntries; i++)
		{
			if(childTable[i].nodeId == msg->nodeID)
			{
				float skewChange = 0, drift = 0;
				int32_t timeSinceLastSkew = 0;
				childExist = 1;
				
				printf("Msg skew: ");
				printfFloat(u2f(msg->skew));
				printf("\n\r");
				
				printf("Old skew: ");
				printfFloat(childTable[i].oldSkew);
				printf("\n\r");
				
				skewChange = u2f(msg->skew) - childTable[i].oldSkew;				
				if(skewChange < 0)
				{
					sign = 0;
					skewChange = -skewChange; // unit is [ms/s]
				}
				printf("Skew change: ");
				printfFloat(skewChange);
				printf("\n\r");
    			printf("Msg time: %ld\n\r",msg->localTime);
    			printf("Table time: %ld\n\r",childTable[i].oldTime);
    			
				timeSinceLastSkew = (msg->localTime - childTable[i].oldTime); // unit is [ms]
				printf("Time since last: %ld s\n\r", timeSinceLastSkew);
				
				if(timeSinceLastSkew != 0) {
					drift = (skewChange*1000)/timeSinceLastSkew;	// unit is [ms/s²]
				} else if((timeSinceLastSkew > 0 && timeSinceLastSkew > (uint32_t)MAX_BEACON_INTERVAL*1000*2) || 
						(timeSinceLastSkew < 0 && -timeSinceLastSkew < (uint32_t)MAX_BEACON_INTERVAL*1000*2)) {
					printf("Unvalid timestamp\n\r");
					break;	
				} 
				printf("Drift: ");
				printfFloat(drift);
				printf("\n\r");
				childTable[i].drift = drift;
				childTable[i].oldSkew = u2f(msg->skew);
				childTable[i].oldTime = msg->localTime;
				
				if(sign == 1)
					atomic driftToTest = drift;
				else 
					atomic driftToTest = -drift;
				
			}
			
			if(childTable[i].drift > maxDrift)
				maxDrift = childTable[i].drift;
		}
		// Create new entry
		if(childExist == 0)
		{
			printf("Child did not exist.\n\r");
			if(childEntries < MAX_CHILDREN)
			{
				childTable[childEntries].nodeId = msg->nodeID;
				childTable[childEntries].oldSkew = u2f(msg->skew);
				childTable[childEntries].oldTime = msg->localTime;
				childEntries++;
			}
		} else {
			updateBeaconPeriod(maxDrift);
		}
		
    }
    
    void clearTable()
    {
        int8_t i;
        for(i = 0; i < MAX_ENTRIES; ++i)
            table[i].state = ENTRY_EMPTY;

        atomic numEntries = 0;
    }

    uint8_t numErrors=0;
    void addNewEntry(TimeSyncMsg *msg)
    {
        int8_t i, freeItem = -1, oldestItem = 0;
        uint32_t age, oldestTime = 0;
        int32_t timeError;

        tableEntries = 0;

        // clear table if the received entry's been inconsistent for some time
        timeError = msg->localTime;
        printf("Msg local time: %lu\n\r",timeError);
        call GlobalTime.local2Global((uint32_t*)(&timeError));
        printf("Global time: %lu\n\r",timeError);
        timeError -= msg->globalTime;
        printf("Time error: %ld\n\r",timeError);
        printfflush();
        if( (is_synced() == SUCCESS) &&
            (timeError > ENTRY_THROWOUT_LIMIT || timeError < -ENTRY_THROWOUT_LIMIT))
        {
        	printf("Eror tooo high\n\r");
            if (++numErrors>3){
                clearTable();
                printf("Clearing table\n\r");
            }
        }
        else
            numErrors = 0;


        for(i = 0; i < MAX_ENTRIES; ++i) {
            age = msg->localTime - table[i].localTime;

            //logical time error compensation
            if( age >= 0x7FFFFFFFL ) {
                table[i].state = ENTRY_EMPTY;
            	printf("Entry %d old\n\r",i);   
            }

            if( table[i].state == ENTRY_EMPTY )
                freeItem = i;
            else
                ++tableEntries;

            if( age >= oldestTime ) {
                oldestTime = age;
                oldestItem = i;
            }
        }
		printfflush();
		
        if( freeItem < 0 )
            freeItem = oldestItem;
        else
            ++tableEntries;

        table[freeItem].state = ENTRY_FULL;

        table[freeItem].localTime = msg->localTime;
        table[freeItem].timeOffset = msg->globalTime - msg->localTime;
        
        //printf("Global msg time: %lu\n\r",msg->globalTime);
        //printf("Local msg time: %lu\n\r",msg->localTime);
        printf("Timeoffset: %li\n\r",table[freeItem].timeOffset);
        printfflush();
    }

    void task processMsg()
    {
        TimeSyncMsg* msg = (TimeSyncMsg*)(call Send.getPayload(processedMsg, sizeof(TimeSyncMsg)));

		if( msg->hop <= outgoingMsg->hop){
			//This is a parent broadcast
			printf("Parent broadcast. Hop: %u vs own %u\n\r",msg->hop, outgoingMsg->hop);
	        if( msg->rootID < outgoingMsg->rootID &&
	            // jw: after becoming the root ignore other roots messages (in send period)
	            ~(heartBeats < IGNORE_ROOT_MSG && outgoingMsg->rootID == TOS_NODE_ID) ){
	            outgoingMsg->rootID = msg->rootID;
	            outgoingMsg->seqNum = msg->seqNum;
	            outgoingMsg->hop = ++(msg->hop);
	        }
	        else if( outgoingMsg->rootID == msg->rootID && (int8_t)(msg->seqNum - outgoingMsg->seqNum) >= 0 ) {
	            outgoingMsg->seqNum = msg->seqNum;
	            outgoingMsg->hop = ++(msg->hop);
	        }
	        else
	        	goto exit;
	            
	
	        call Leds.led0Toggle();
	        if( outgoingMsg->rootID < TOS_NODE_ID )
	            heartBeats = 0;
	
	        addNewEntry(msg);
	        calculateConversion();
	        outgoingMsg->skew = f2u(skew);
	        signal TimeSyncNotify.msg_received();
        } else if(msg->hop > outgoingMsg->hop) {
        	// This is a child broadcast
        	//printf("Child broadcast\n\r");
        	printf("Child broadcast. Hop: %u vs own %u\n\r",msg->hop, outgoingMsg->hop);
        	handleNewChildSkew(msg);
        }
        
    exit:
    	printf("Done processing message.\n\n\r");
        printfflush();
        state &= ~STATE_PROCESSING;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
        if( (state & STATE_PROCESSING) == 0 ) {
            message_t* old = processedMsg;
			
			//printf("Receive.receive(): state=%u \n\r", state);
      					
            processedMsg = msg;
            ((TimeSyncMsg*)(payload))->localTime = call TimeSyncPacket.eventTime(msg);

			//printf("Timestamping done \n\r");
      		printfflush();
            state |= STATE_PROCESSING;
            post processMsg();
            return old;
        }
		
		printf("Receive.receive(): state=Processing: %u \n\r", state);
  		printfflush();
        return msg;
    }

    task void sendMsg()
    {
        uint32_t localTime, globalTime;

        globalTime = localTime = call GlobalTime.getLocalTime();
        call GlobalTime.local2Global(&globalTime);

        // we need to periodically update the reference point for the root
        // to avoid wrapping the 32-bit (localTime - localAverage) value
        if( outgoingMsg->rootID == TOS_NODE_ID ) {
            if( (int32_t)(localTime - localAverage) >= 0x20000000 )
            {
                atomic
                {
                    localAverage = localTime;
                    offsetAverage = globalTime - localTime;
                }
                printf("Update local times\n\n\r");
                printfflush();
            }
        }
        else if( heartBeats >= ROOT_TIMEOUT ) {
            heartBeats = 0; //to allow ROOT_SWITCH_IGNORE to work
            outgoingMsg->rootID = TOS_NODE_ID;
            ++(outgoingMsg->seqNum); // maybe set it to zero?
            outgoingMsg->hop = 0;
        }

        outgoingMsg->globalTime = globalTime;
		
        // we don't send time sync msg, if we don't have enough data
        if( numEntries < ENTRY_SEND_LIMIT && outgoingMsg->rootID != TOS_NODE_ID ){
            ++heartBeats;
            state &= ~STATE_SENDING;
        }
        else if( call Send.send(AM_BROADCAST_ADDR, &outgoingMsgBuffer, TIMESYNCMSG_LEN, localTime ) != SUCCESS ){
            state &= ~STATE_SENDING;
            signal TimeSyncNotify.msg_sent();
        }
    }

    event void Send.sendDone(message_t* ptr, error_t error)
    {
        if (ptr != &outgoingMsgBuffer)
          return;

        if(error == SUCCESS)
        {
            ++heartBeats;
            call Leds.led1Toggle();

            if( outgoingMsg->rootID == TOS_NODE_ID )
                ++(outgoingMsg->seqNum);
        }

        state &= ~STATE_SENDING;
        signal TimeSyncNotify.msg_sent();
    }

    void timeSyncMsgSend()
    {
        if( outgoingMsg->rootID == 0xFFFF && ++heartBeats >= ROOT_TIMEOUT ) {
            outgoingMsg->seqNum = 0;
            outgoingMsg->rootID = TOS_NODE_ID;
            outgoingMsg->hop = 0;
        }

        if( outgoingMsg->rootID != 0xFFFF && (state & STATE_SENDING) == 0 ) {
           state |= STATE_SENDING;
           post sendMsg();
        }
    }

    event void Timer.fired()
    {
      	printf("Timer.fired(): State = %u\n\r",state);
      	printfflush();
      if (mode == TS_TIMER_MODE) {
        timeSyncMsgSend();
      }
      else if(mode == TS_DFTSP_MODE) {
      	call Timer.startOneShot((uint32_t)1000*beaconPeriod);
  		timeSyncMsgSend();
  	  } else
        call Timer.stop();
    }

    command error_t TimeSyncMode.setMode(uint8_t mode_){
        if (mode == mode_)
            return SUCCESS;

        if (mode_ == TS_USER_MODE){
            call Timer.startPeriodic((uint32_t)1000*beaconPeriod);
        }
        else
            call Timer.stop();

        mode = mode_;
        return SUCCESS;
    }

    command uint8_t TimeSyncMode.getMode(){
        return mode;
    }

    command error_t TimeSyncMode.send(){
        if (mode == TS_USER_MODE){
            timeSyncMsgSend();
            return SUCCESS;
        }
        return FAIL;
    }

    command error_t Init.init()
    {
        atomic{
            skew = 0.0;
            localAverage = 0;
            offsetAverage = 0;
    		beaconPeriod = MIN_BEACON_INTERVAL;
    		driftToTest = 0;
        };
		
		clearChildTable();
        clearTable();

        atomic outgoingMsg = (TimeSyncMsg*)call Send.getPayload(&outgoingMsgBuffer, sizeof(TimeSyncMsg));
        outgoingMsg->rootID = 0xFFFF;
        outgoingMsg->hop = 0xFF;

        processedMsg = &processedMsgBuffer;
        state = STATE_INIT;

        return SUCCESS;
    }

    event void Boot.booted()
    {
      call RadioControl.start();
      call StdControl.start();
    }

    command error_t StdControl.start()
    {
        mode = TS_DFTSP_MODE;
        heartBeats = 0;
        outgoingMsg->nodeID = TOS_NODE_ID;
        call Timer.startOneShot((uint32_t)1000*beaconPeriod);

        return SUCCESS;
    }

    command error_t StdControl.stop()
    {
        call Timer.stop();
        return SUCCESS;
    }

    async command float     TimeSyncInfo.getSkew() { return skew; }
    async command uint32_t  TimeSyncInfo.getOffset() { return offsetAverage; }
    async command uint32_t  TimeSyncInfo.getSyncPoint() { return localAverage; }
    async command uint16_t  TimeSyncInfo.getRootID() { return outgoingMsg->rootID; }
    async command uint8_t   TimeSyncInfo.getSeqNum() { return outgoingMsg->seqNum; }
    async command uint8_t   TimeSyncInfo.getNumEntries() { return numEntries; }
    async command uint8_t   TimeSyncInfo.getHeartBeats() { return heartBeats; }
	async command uint32_t 	TimeSyncInfo.getDrift(){ return f2u(skew);}
	async command uint8_t 	TimeSyncInfo.getSyncPeriod(){return beaconPeriod;}

    default event void TimeSyncNotify.msg_received(){}
    default event void TimeSyncNotify.msg_sent(){}

    event void RadioControl.startDone(error_t error){}
    event void RadioControl.stopDone(error_t error){}

	
	
}
