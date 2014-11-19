
configuration FTSPAppC{
}
implementation {
	components MainC;
	components TimeSyncC;
	
	MainC.SoftwareInit -> TimeSyncC;
	TimeSyncC -> MainC.Boot;
	
}