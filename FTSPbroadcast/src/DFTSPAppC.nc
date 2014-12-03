
configuration DFTSPAppC{
}
implementation {
	components MainC;
	components TimeSyncC;
	
	
	TimeSyncC -> MainC.Boot;
	
}