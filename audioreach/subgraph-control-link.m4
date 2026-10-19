# Copyright, Linaro Ltd, 2025
# SPDX-License-Identifier: BSD-3-Clause
include(`util/util.m4') dnl
dnl AR_SUBGRAPH_CONTROL_LINK(index, dai-index, sub-graph-id, perf-mode, dir, sid,
dnl                          [static-sample-rate, static-bit-width, static-num-channels])
dnl
dnl Emits the subgraph vendor-tuples block. The optional trailing three
dnl args attach a static media format to the subgraph via
dnl AR_TKN_U32_SUB_GRAPH_SAMPLE_RATE / BIT_WIDTH / NUM_CHANNELS. The
dnl kernel audioreach driver prefers that over the opening DAI's cfg
dnl when configuring CODEC_DMA / SP / SP_VI modules inside this
dnl subgraph. Needed when a subgraph is co-opened via DAI_INDEX sharing
dnl and the opener's cfg is for a different port.
dnl
dnl If the trailing args are omitted and $2 (dai-index) does not match
dnl DEVICE_DAI_ID (i.e. the subgraph is being co-opened under a
dnl different DAI's graph_info[]), the static format is auto-derived
dnl from the DEVICE_FORMAT / DEVICE_MAX_RATE / DEVICE_MAX_CHANNELS
dnl values the enclosing DEVICE_SG_ADD call declared. When $2 matches
dnl DEVICE_DAI_ID (the natural opener case), no static tokens are
dnl emitted and the opener's cfg governs the module format.
define(`AR_SUBGRAPH_CONTROL_LINK',
`'
`SectionVendorTuples."NAME_PREFIX.sub_graph$1_tuples" {'
`        tokens "audioreach_tokens"'
`        tuples."word.u32_data" {'
`                AR_TKN_U32_SUB_GRAPH_INSTANCE_ID STR($3)'
`                AR_TKN_DAI_INDEX STR($2)'
`                AR_TKN_U32_SUB_GRAPH_PERF_MODE STR($4)'
`                AR_TKN_U32_SUB_GRAPH_DIRECTION STR($5)'
`                AR_TKN_U32_SUB_GRAPH_SCENARIO_ID STR($6)'
`ifelse(`$7', `', `ifelse($2, DEVICE_DAI_ID, `', `                AR_TKN_U32_SUB_GRAPH_SAMPLE_RATE STR(DEVICE_MAX_RATE)
                AR_TKN_U32_SUB_GRAPH_BIT_WIDTH STR(FMT_BIT_WIDTH(DEVICE_FORMAT))
                AR_TKN_U32_SUB_GRAPH_NUM_CHANNELS STR(DEVICE_MAX_CHANNELS)')', `                AR_TKN_U32_SUB_GRAPH_SAMPLE_RATE STR($7)
                AR_TKN_U32_SUB_GRAPH_BIT_WIDTH STR($8)
                AR_TKN_U32_SUB_GRAPH_NUM_CHANNELS STR($9)')'
`        }'
`}'
`'
`SectionData."NAME_PREFIX.sub_graph$1_data" {'
`        tuples ["NAME_PREFIX.sub_graph$1_tuples"'
`                "NAME_PREFIX.control_link$1_tuples"]'
`}') dnl
