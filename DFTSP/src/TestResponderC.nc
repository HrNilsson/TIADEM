
#include "TestResponse.h"
#include "printf.h"

module TestResponderC
{
	uses
	{
		interface GlobalTime<TMilli>;
        interface TimeSyncInfo;
        interface Receive;
        interface TimeSyncAMSend<TMilli,uint32_t> as AMSend;
        interface Packet;
        interface Leds;
        //interface PacketTimeStamp<TMilli,uint32_t>;
        interface Boot;
        interface SplitControl as RadioControl;
	}
}

implementation
{

	message_t msg;
    bool locked = FALSE;
    SyncReportMsg* payloadPtr;
    nx_uint32_t time;

    event void Boot.booted() {
        call RadioControl.start();
        call Leds.led1On();
    }

    event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len)
    {
        call Leds.led2Toggle();
        printf("Received packet\n\r");
        
        if (!locked)
        {
        	printf("Not locked\n\r");
        	printfflush();
			payloadPtr = (SyncReportMsg*)call Packet.getPayload(&msg, sizeof(SyncReportMsg));
			
			payloadPtr->nodeID = TOS_NODE_ID;
			
			time = call GlobalTime.getLocalTime();
			call GlobalTime.local2Global((uint32_t*)&time);
			payloadPtr->globalTimeEst = time;
			
			payloadPtr->seqNum = call TimeSyncInfo.getSeqNum();
			

            if (call AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(SyncReportMsg),0) == SUCCESS) {
              locked = TRUE;
            }
        }

        return msgPtr;
    }

    event void AMSend.sendDone(message_t* ptr, error_t success) {
        locked = FALSE;
        return;
    }

    event void RadioControl.startDone(error_t err) {}
    event void RadioControl.stopDone(error_t error){}	
}