
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
        interface Read<uint16_t>;
	}
}

implementation
{

	message_t msg;
    bool locked = FALSE;
    SyncReportMsg* payloadPtr;
    uint32_t time;
    uint16_t temp;

    event void Boot.booted() {
    	temp = 0;
    	call Read.read();
        call RadioControl.start();
        call Leds.led1On();
    }

    event message_t* Receive.receive(message_t* msgPtr, void* payload, uint8_t len)
    {
    	call Read.read();
        call Leds.led2Toggle();
        printf("Received packet\n\r");
        
        if (!locked)
        {
        	printf("Not locked\n\r");
        	printfflush();
			payloadPtr = (SyncReportMsg*)call Packet.getPayload(&msg, sizeof(SyncReportMsg));
			
			payloadPtr->nodeID = TOS_NODE_ID;
			
			call GlobalTime.getGlobalTime(&time);
			payloadPtr->globalTimeEst = time;
			payloadPtr->syncPeriod = call TimeSyncInfo.getSyncPeriod();
			payloadPtr->drift = call TimeSyncInfo.getDrift();
			payloadPtr->seqNum = call TimeSyncInfo.getSeqNum();
			payloadPtr->temp = temp;
			

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

	event void Read.readDone(error_t result, uint16_t val){
		if(result == SUCCESS)
			temp = val;
	}
}