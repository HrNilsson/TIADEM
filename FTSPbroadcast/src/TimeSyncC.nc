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
 * Author: Miklos Maroti, Brano Kusy, Janos Sallai
 * Date last modified: 3/17/03
 * Ported to T2: 3/17/08 by Brano Kusy (branislav.kusy@gmail.com)
 */

#include "TimeSyncMsg.h"
#include "Timer.h"
#define TIMESYNC_LEDS

configuration TimeSyncC
{
  uses interface Boot;
  provides interface StdControl;
}

implementation
{
  components new TimeSyncP(TMilli);

  StdControl      =   TimeSyncP;
  Boot            =   TimeSyncP;  

  components TimeSyncMessageC as ActiveMessageC;
  TimeSyncP.RadioControl    ->  ActiveMessageC;
  TimeSyncP.Send            ->  ActiveMessageC.TimeSyncAMSendMilli[AM_DTEST_FTSP_MSG_DOWN];
  TimeSyncP.Receive         ->  ActiveMessageC.Receive[AM_DTEST_FTSP_MSG_UP];
  TimeSyncP.TimeSyncPacket  ->  ActiveMessageC;

  components new TimerMilliC() as TimerC;
  TimeSyncP.Timer ->  TimerC;

#if defined(TIMESYNC_LEDS)
  components LedsC;
#else
  components NoLedsC as LedsC;
#endif
  TimeSyncP.Leds  ->  LedsC;

  components SerialActiveMessageC as PCSerial;
  TimeSyncP.SerialControl -> PCSerial;
  TimeSyncP.PCReceive -> PCSerial.Receive[AM_PC_SERIAL];
  TimeSyncP.PCTransmit -> PCSerial.AMSend[AM_PC_SERIAL];
  TimeSyncP.PCPacket -> PCSerial; 
}
