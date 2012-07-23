/**
@file	 AsyncAudioElasticFifo.cpp
@brief   A FIFO for handling audio samples
@author  Tobias Blomberg / SM0SVX
@date	 2007-10-06

Implements a jitter-tolerant FIFO for storing samples.

\verbatim
Async - A library for programming event driven applications
Copyright (C) 2003-2009  Tobias Blomberg / SM0SVX

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
\endverbatim
*/



/****************************************************************************
 *
 * System Includes
 *
 ****************************************************************************/

#include <iostream>
#include <cstring>
#include <cassert>


/****************************************************************************
 *
 * Project Includes
 *
 ****************************************************************************/



/****************************************************************************
 *
 * Local Includes
 *
 ****************************************************************************/

#include "AsyncAudioElasticFifo.h"



/****************************************************************************
 *
 * Namespaces to use
 *
 ****************************************************************************/

using namespace std;
using namespace Async;


/****************************************************************************
 *
 * Defines & typedefs
 *
 ****************************************************************************/



/****************************************************************************
 *
 * Local class definitions
 *
 ****************************************************************************/



/****************************************************************************
 *
 * Prototypes
 *
 ****************************************************************************/



/****************************************************************************
 *
 * Exported Global Variables
 *
 ****************************************************************************/



/****************************************************************************
 *
 * Local Global Variables
 *
 ****************************************************************************/



/****************************************************************************
 *
 * Public member functions
 *
 ****************************************************************************/

AudioElasticFifo::AudioElasticFifo(unsigned fifo_size)
  : fifo(0), fifo_size(fifo_size), head(0), tail(0),
    prebuf(true), stream_state(STREAM_IDLE)
{
  assert(fifo_size > 0);
  fifo = new float[fifo_size];
} /* AudioElasticFifo */


AudioElasticFifo::~AudioElasticFifo(void)
{
  delete [] fifo;
} /* ~AudioElasticFifo */


void AudioElasticFifo::setSize(unsigned new_size)
{
  assert(fifo_size > 0);
  if (new_size != fifo_size)
  {
    delete [] fifo;
    fifo_size = new_size;
    fifo = new float[fifo_size];
  }
  clear();
} /* AudioElasticFifo::setSize */


unsigned AudioElasticFifo::samplesInFifo(bool ignore_prebuf) const
{
  unsigned samples_in_buffer = (head - tail + fifo_size) % fifo_size;

  if (!ignore_prebuf && prebuf && (stream_state != STREAM_FLUSHING))
  {
    if (samples_in_buffer < (fifo_size >> 1))
    {
      return 0;
    }
  }

  return samples_in_buffer;

} /* AudioElasticFifo::samplesInFifo */


void AudioElasticFifo::clear(void)
{
  bool was_empty = empty();
  
  tail = head = 0;
  prebuf = true;
  
  if ((stream_state == STREAM_FLUSHING) && !was_empty)
  {
    sinkFlushSamples();
  }
} /* AudioElasticFifo::clear */


int AudioElasticFifo::writeSamples(const float *samples, int count)
{
  assert(count > 0);

  if (stream_state != STREAM_ACTIVE)
  {
    stream_state = STREAM_ACTIVE;
    sinkAvailSamples();
  }

  int written = 0;
  while (written < count)
  {
    fifo[head] = samples[written++];
    head = (head + 1) % fifo_size;
    if (head == tail)
    {
        // Throw away the first half of the buffer.
      tail = (tail + (fifo_size >> 1)) % fifo_size;
    }
  }
  
  if (samplesInFifo())
  {
    prebuf = false;
  }

  return written;
  
} /* writeSamples */


void AudioElasticFifo::availSamples(void)
{
  stream_state = STREAM_ACTIVE;
  sinkAvailSamples();
} /* AudioElasticFifo::availSamples */


void AudioElasticFifo::flushSamples(void)
{
  stream_state = STREAM_FLUSHING;
  if (empty())
  {
    sinkFlushSamples();
  }
  else
  {
    flushSamplesFromFifo();
  }
} /* AudioElasticFifo::flushSamples */


void AudioElasticFifo::requestSamples(int count)
{
  if (prebuf)
  {
    writeZeroBlock(count);
  }
  else
  {
    writeSamplesFromFifo(count);
  }
} /* AudioElasticFifo::requestSamples */


void AudioElasticFifo::discardSamples(void)
{
  clear();
  sourceDiscardSamples();
} /* AudioElasticFifo::discardSamples */


/****************************************************************************
 *
 * Protected member functions
 *
 ****************************************************************************/


void AudioElasticFifo::allSamplesFlushed(void)
{
  if (empty())
  {
    if (stream_state == STREAM_FLUSHING)
    {
      stream_state = STREAM_IDLE;
      sourceAllSamplesFlushed();
    }
    prebuf = true;
  }
} /* AudioElasticFifo::allSamplesFlushed */



/****************************************************************************
 *
 * Private member functions
 *
 ****************************************************************************/


void AudioElasticFifo::writeSamplesFromFifo(int count)
{
  unsigned samples_from_fifo = min((unsigned)count, samplesInFifo());

  //cerr << "samples_from_fifo=" << samples_from_fifo << " " << samplesInFifo() << endl;

  while (samples_from_fifo > 0)
  {
    unsigned to_end_of_fifo = min(samples_from_fifo, fifo_size - tail);
    unsigned ret = sinkWriteSamples(fifo + tail, to_end_of_fifo);
      
    tail += ret;
    tail %= fifo_size;
    samples_from_fifo -= ret;

    if (ret < to_end_of_fifo)
    {
      break;
    }
  }
  
  if (empty())
  {
    if (stream_state == STREAM_FLUSHING)
    {
      sinkFlushSamples();
    }
    prebuf = true;
  }
  
} /* writeSamplesFromFifo */


void AudioElasticFifo::writeZeroBlock(int count)
{
  while (count > 0)
  {
    float buf[256];
    int len = min(count, 256);
    memset(buf, 0, len * sizeof(float));

    int ret = sinkWriteSamples(buf, len);
    count -= ret;

    if (ret < len)
    {
      break;
    }
  }

  if (stream_state == STREAM_FLUSHING)
  {
    clear();
  }

} /* writeZero */


void AudioElasticFifo::flushSamplesFromFifo(void)
{
  unsigned samples_from_fifo = samplesInFifo();

  //cerr << "samples_from_fifo=" << samples_from_fifo << endl;

  while (samples_from_fifo > 0)
  {
    unsigned to_end_of_fifo = min(samples_from_fifo, fifo_size - tail);
    unsigned ret = sinkWriteSamples(fifo + tail, to_end_of_fifo);
    
    tail += ret;
    tail %= fifo_size;
    samples_from_fifo -= ret;

    if (ret < to_end_of_fifo)
    {
      break;
    }
  }

  if (empty())
  {
    if (stream_state == STREAM_FLUSHING)
    {
      sinkFlushSamples();
    }
    prebuf = true;
  }

} /* flushSamplesFromFifo */


/*
 * This file has not been truncated
 */