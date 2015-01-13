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

#pragma once

#include "types.h"
#include "string_database.h"

namespace firepony {

namespace SequenceDataMask
{
    enum
    {
        BASES       = 0x001,
        QUALITIES   = 0x002,
        NAMES       = 0x004,
    };
}

template <target_system system>
struct sequence_data_storage
{
    // the generation counter is used to check if the GPU vs CPU versions are out of date
    uint32 generation;

    uint32 data_mask;
    uint32 num_sequences;

    packed_vector<system, 4> bases;
    vector<system, uint8> qualities;

    vector<system, uint32> sequence_id;
    // note: bases and quality indexes may not match if sequences are padded to dword length
    vector<system, uint64> sequence_bp_start;
    vector<system, uint64> sequence_bp_len;
    vector<system, uint64> sequence_qual_start;
    vector<system, uint64> sequence_qual_len;

    CUDA_HOST sequence_data_storage()
        : generation(0),
          num_sequences(0)
    { }

    struct const_view
    {
        uint32 data_mask;
        uint32 num_sequences;

        typename packed_vector<system, 4>::const_view bases;
        typename vector<system, uint8>::const_view qualities;
        typename vector<system, uint32>::const_view sequence_id;
        typename vector<system, uint64>::const_view sequence_bp_start;
        typename vector<system, uint64>::const_view sequence_bp_len;
        typename vector<system, uint64>::const_view sequence_qual_start;
        typename vector<system, uint64>::const_view sequence_qual_len;
    };

    CUDA_HOST operator const_view() const
    {
        const_view v = {
                data_mask,
                num_sequences,
                bases,
                qualities,
                sequence_id,
                sequence_bp_start,
                sequence_bp_len,
                sequence_qual_start,
                sequence_qual_len,
        };

        return v;
    }
};

struct sequence_data_host : public sequence_data_storage<host>
{
    string_database sequence_names;
};

} // namespace firepony
