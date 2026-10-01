# Copyright, Linaro Ltd, 2025
# SPDX-License-Identifier: BSD-3-Clause
include(`util/util.m4') dnl
dnl AR_CONTROL_LINK(index, iid, peer1-iid, peer1-port, peer2-iid, peer2-port, intent0, intent1, intent2, intent3)
define(`AR_CONTROL_LINK',
`'
`SectionVendorTuples."NAME_PREFIX.control_link$1_tuples" {'
`        tokens "audioreach_tokens"'
`'
`        tuples."word.u32_data" {'
`                AR_TKN_U32_CONTROL_LINK_IID STR($2)'
`                AR_TKN_U32_CONTROL_LINK_PEER1_MOD_IID STR($3)'
`                AR_TKN_U32_CONTROL_LINK_PEER1_MOD_PORT_ID STR($4)'
`                AR_TKN_U32_CONTROL_LINK_PEER2_MOD_IID STR($5)'
`                AR_TKN_U32_CONTROL_LINK_PEER2_MOD_PORT_ID STR($6)'
`                AR_TKN_U32_CONTROL_LINK_INTENT0 STR($7)'
`                AR_TKN_U32_CONTROL_LINK_INTENT1 STR($8)'
`                AR_TKN_U32_CONTROL_LINK_INTENT2 STR($9)'
`                AR_TKN_U32_CONTROL_LINK_INTENT3 STR($10)'
`        }'
`}') dnl
