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

#include "firepony_context.h"
#include "util.h"

namespace firepony {

template <target_system system>
void firepony_context<system>::update_databases(const sequence_database_storage<system>& reference_db,
                                                const variant_database_storage<system>& variant_db)
{
    // update our database pointers
    const_cast<sequence_database_storage<system>&> (this->reference_db) = reference_db;
    const_cast<variant_database_storage<system>&> (this->variant_db) = variant_db;
}
METHOD_INSTANTIATE(firepony_context, update_databases);

template <target_system system>
void firepony_context<system>::start_batch(const alignment_batch<system>& batch)
{
    // initialize the read order with 0..N
    active_read_list.resize(batch.host->num_reads);
    thrust::copy(lift::backend_policy<system>::execution_policy(),
                 thrust::make_counting_iterator(0),
                 thrust::make_counting_iterator(0) + batch.host->num_reads,
                 active_read_list.begin());

    // set up the active location list to cover all of the current batch
    active_location_list.resize(batch.host->reads.size());
    // mark all BPs as active
    thrust::fill(lift::backend_policy<system>::execution_policy(),
                 active_location_list.m_storage.begin(),
                 active_location_list.m_storage.end(),
                 0xffffffff);
}
METHOD_INSTANTIATE(firepony_context, start_batch);

template <target_system system>
void firepony_context<system>::end_batch(const alignment_batch<system>& batch)
{
    stats.total_reads += batch.host->num_reads;
    stats.num_batches++;
}
METHOD_INSTANTIATE(firepony_context, end_batch);

} // namespace firepony

