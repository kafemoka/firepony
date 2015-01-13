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

#include <gamgee/sam/sam_reader.h>
#include "../alignment_data.h"
#include "reference.h"

namespace firepony {

struct alignment_file
{
private:
    gamgee::SamReader<gamgee::SamIterator> file;
    gamgee::SamHeader gamgee_header;
    gamgee::SamIterator iterator;

    // map read group identifiers in tag data to read group names from the header
    // the read group name is either taken from the platform unit string if present, or else it's just the identifier itself
    std::map<std::string, std::string> read_group_id_to_name;

public:
    alignment_header_host header;

    alignment_file(const char *fname);
    ~alignment_file();

    bool next_batch(alignment_batch_host *batch, uint32 data_mask, reference_file_handle *reference, const uint32 batch_size = 100000);
    const char *get_sequence_name(uint32 id);
};

} // namespace firepony

