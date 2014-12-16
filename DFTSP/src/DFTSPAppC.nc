#define DEBUG_WITH_PRINTF

#ifdef DEBUG_WITH_PRINTF
	#include "printf.h"
#endif //DEBUG_WITH_PRINTF	

#include "TestResponse.h"

configuration DFTSPAppC{
}
implementation {
	components MainC;
	components TimeSyncC;
	
	MainC.SoftwareInit -> TimeSyncC;
	TimeSyncC -> MainC.Boot;
	
	// Test Responder 
	components TestResponderC as App;
    App.Boot -> MainC;

    components TimeSyncMessageC as ActiveMessageC;
    App.RadioControl -> ActiveMessageC;
    App.Receive -> ActiveMessageC.Receive[AM_DTEST_FTSP_MSG_DOWN];
    App.AMSend -> ActiveMessageC.TimeSyncAMSendMilli[AM_DTEST_FTSP_MSG_UP];
    App.Packet -> ActiveMessageC;

    components LedsC;

    App.GlobalTime -> TimeSyncC;
    App.TimeSyncInfo -> TimeSyncC;
    App.Leds -> LedsC;
	
	components new SensirionSht11C() as Sensor;
	App.Read -> Sensor.Temperature;
	
#ifdef DEBUG_WITH_PRINTF
	// Printf specific
	components PrintfC;
  	components SerialStartC;
#endif //DEBUG_WITH_PRINTF	
}