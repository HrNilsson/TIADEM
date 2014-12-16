
configuration DFTSPBroadcastAppC{
}
implementation {
	components MainC;
	components TimeSyncC;
	
	TimeSyncC -> MainC.Boot;
	
}