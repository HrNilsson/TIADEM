
#if defined(TESTRESPONSE_H)
#else
#define TESTRESPONSE_H

typedef nx_struct SyncReportMsg
{
	nx_uint16_t	nodeID;			// the node if of the sender
	nx_uint32_t	globalTimeEst;	// the senders estimation of the global time
	nx_uint8_t  syncPeriod;		// the senders synchronization period
	nx_int16_t  drift;			// the senders estimation of its child's drift
	nx_int16_t  temp;			// the senders temperature measurement
	nx_uint8_t	seqNum;		// sequence number for the root
} SyncReportMsg;


enum
{
	AM_DTEST_FTSP_MSG = 150
};

#endif