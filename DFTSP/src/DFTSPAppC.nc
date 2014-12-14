#define DEBUG_WITH_PRINTF

#ifdef DEBUG_WITH_PRINTF
	#include "printf.h"
#endif //DEBUG_WITH_PRINTF	

configuration DFTSPAppC{
}
implementation {
	components MainC;
	components TimeSyncC;
	
	MainC.SoftwareInit -> TimeSyncC;
	TimeSyncC -> MainC.Boot;
	
#ifdef DEBUG_WITH_PRINTF
	// Printf specific
	components PrintfC;
  	components SerialStartC;
#endif //DEBUG_WITH_PRINTF	
}