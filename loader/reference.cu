/*
 * Firepony
 * Copyright (c) 2014-2015, NVIDIA CORPORATION. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *    * Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *    * Neither the name of the NVIDIA CORPORATION nor the
 *      names of its contributors may be used to endorse or promote products
 *      derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL NVIDIA CORPORATION BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <gamgee/fastq.h>
#include <gamgee/fastq_iterator.h>
#include <gamgee/fastq_reader.h>

#include <string>
#include <sstream>
#include <fstream>
#include <algorithm>

#include "../sequence_data.h"
#include "../string_database.h"

#include "reference.h"
#include "../command_line.h"

#include "../device/util.h"
#include "../device/from_nvbio/dna.h"

namespace firepony {

#include <thrust/iterator/transform_iterator.h>

struct iupac16 : public thrust::unary_function<char, uint8>
{
    uint8 operator() (char in)
    {
        return from_nvbio::char_to_iupac16(in);
    }
};

static bool load_record(sequence_data_host *output, const gamgee::Fastq& record, uint32 data_mask)
{
    auto& h = *output;
    h.data_mask = data_mask;

    h.num_sequences++;

    if (data_mask & SequenceDataMask::BASES)
    {
        std::string sequence = record.sequence();

        const size_t seq_start = h.bases.size();
        const size_t seq_len = sequence.size();

        h.sequence_bp_start.push_back(seq_start);
        h.sequence_bp_len.push_back(seq_len);

        h.bases.resize(seq_start + seq_len);

        assign(sequence.size(),
               thrust::make_transform_iterator(sequence.begin(), iupac16()),
               h.bases.stream_at_index(seq_start));
    }

    if (data_mask & SequenceDataMask::QUALITIES)
    {
        assert(!"unimplemented");
        return false;
    }

    if (data_mask & SequenceDataMask::NAMES)
    {
        uint32 seq_id = output->sequence_names.insert(record.name());
        h.sequence_id.push_back(seq_id);
    }

    h.generation++;
    return true;
}

// loader for sequence data
static bool load_reference(sequence_data_host *output, const char *filename, uint32 data_mask)
{
    for (gamgee::Fastq& record : gamgee::FastqReader(std::string(filename)))
    {
        bool ret = load_record(output, record, data_mask);
        if (ret == false)
            return false;
    }

    return true;
}

static bool load_one_sequence(sequence_data_host *output, const std::string filename, size_t file_offset, uint32 data_mask)
{
    // note: we can't reuse the existing ifstream as gamgee for some reason wants to take ownership of the pointer and destroy it
    std::ifstream *file_stream = new std::ifstream();
    file_stream->open(filename);
    file_stream->seekg(file_offset);

    gamgee::FastqReader reader(file_stream);
    gamgee::Fastq record = *(reader.begin());

    return load_record(output, record, data_mask);
}

reference_file_handle::reference_file_handle(const std::string filename, uint32 data_mask, uint32 consumers)
  : filename(filename), data_mask(data_mask), consumers(consumers)
{
    sequence_mutexes.resize(consumers);
}

void reference_file_handle::consumer_lock(const uint32 consumer_id)
{
    sequence_mutexes[consumer_id].lock();
}

void reference_file_handle::consumer_unlock(const uint32 consumer_id)
{
    sequence_mutexes[consumer_id].unlock();
}

bool reference_file_handle::load_index()
{
    std::string index_fname;
    std::ifstream index_fstream;

    // check if we have an index
    index_fname = filename + ".fai";
    index_fstream.open(index_fname);
    if (index_fstream.fail())
    {
        index_available = false;
        return false;
    }

    std::string line;
    while(std::getline(index_fstream, line))
    {
        // faidx format: <sequence name> <sequence len> <file offset> <line blen> <line len>
        // fields are separated by \t

        // replace all \t with spaces to ease parsing
        std::replace(line.begin(), line.end(), '\t', ' ');

        std::stringstream ss(line);
        std::string name;
        size_t len;
        size_t offset;

        ss >> name;
        ss >> len;
        ss >> offset;

        reference_index[string_database::hash(name)] = offset;
    }

    index_available = true;
    return true;
}

reference_file_handle *reference_file_handle::open(const std::string filename, uint32 data_mask, uint32 consumers)
{
    reference_file_handle *handle = new reference_file_handle(filename, data_mask, consumers);

    if (!handle->load_index())
    {
        // no index present, load entire reference
        fprintf(stderr, "WARNING: index not available for reference file %s, loading entire reference\n", filename.c_str());
        load_reference(&handle->sequence_data, filename.c_str(), data_mask);
    } else {
        fprintf(stderr, "loaded index for %s\n", filename.c_str());

        handle->file_handle.open(filename);
        if (handle->file_handle.fail())
        {
            fprintf(stderr, "error opening %s\n", filename.c_str());
            delete handle;
            return nullptr;
        }
    }

    return handle;
}

void reference_file_handle::producer_lock(void)
{
    for(uint32 id = 0; id < sequence_mutexes.size(); id++)
        consumer_lock(id);
}

void reference_file_handle::producer_unlock(void)
{
    for(uint32 id = 0; id < sequence_mutexes.size(); id++)
        consumer_unlock(id);
}

bool reference_file_handle::make_sequence_available(const std::string& sequence_name)
{
    if (!index_available)
    {
        return (sequence_data.sequence_names.lookup(sequence_name) != uint32(-1));
    } else {
        if (sequence_data.sequence_names.lookup(sequence_name) == uint32(-1))
        {
            // search for the sequence name in our index
            auto it = reference_index.find(string_database::hash(sequence_name));
            if (it == reference_index.end())
            {
                // sequence not found in index, can't load
                return false;
            }

            // found it, grab the offset
            size_t offset = it->second;

            // we must seek backwards to the beginning of the header
            // (faidx points at the beginning of the sequence data, but gamgee needs to parse the header)
            char c;
            do {
                file_handle.seekg(offset);
                file_handle >> c;
                file_handle.seekg(offset);

                if (c != '>')
                    offset--;
            } while(c != '>');

            producer_lock();
            bool ret = load_one_sequence(&sequence_data, filename, offset, data_mask);
            producer_unlock();

            fprintf(stderr, "+");
            fflush(stderr);

            return ret;
        } else {
            return true;
        }
    }
}

} // namespace firepony
