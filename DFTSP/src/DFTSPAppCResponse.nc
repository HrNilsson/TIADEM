
#include "TestResponse.h"
configuration DFTSPAppC{
}
implementation {
	components MainC;
	components TimeSyncC;
	
	MainC.SoftwareInit -> TimeSyncC;
	//TimeSyncC -> MainC.Boot;
	
    components TestResponderC as App;
    App.Boot -> MainC;

    components TimeSyncMessageC as ActiveMessageC;
    App.RadioControl -> ActiveMessageC;
    App.Receive -> ActiveMessageC.Receive[AM_DTEST_FTSP_MSG];
    App.AMSend -> ActiveMessageC.TimeSyncAMSendMilli[AM_DTEST_FTSP_MSG];
    App.Packet -> ActiveMessageC;

    components LedsC;

    App.GlobalTime -> TimeSyncC;
    App.TimeSyncInfo -> TimeSyncC;
    App.Leds -> LedsC;
	
}