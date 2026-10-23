# Copyright, Linaro Ltd, 2025
# SPDX-License-Identifier: BSD-3-Clause
include(`audioreach/audioreach.m4') dnl
include(`util/pcm.m4') dnl
include(`audioreach/subgraph.m4') dnl
include(`audioreach/subgraph-control-link.m4') dnl
include(`audioreach/container.m4') dnl
include(`audioreach/control_link.m4') dnl
include(`audioreach/module_mfc.m4') dnl
include(`audioreach/module_log.m4') dnl
include(`audioreach/module_codec_dma.m4') dnl
include(`audioreach/module_speaker_protection_t14s.m4') dnl
include(`util/mixer.m4') dnl
dnl
#
# SubGraph for Device Backend
#
#  ______________________
# |   Sub Graph          |
# | [LOG] -> [DEVICE EP] |
# |______________________|

undefine(`CDC_DMA_MODULE_IID') dnl
undefine(`LOG_MODULE_IID') dnl
undefine(`SP_MODULE_IID') dnl
undefine(`SG_INDEX') dnl
undefine(`CONTAINER_INDEX') dnl

undefine(`DEVICE_PERF_MODE') dnl
undefine(`DEVICE_DIRECTION') dnl
undefine(`CONT_SENARIO_ID') dnl
undefine(`CONT_CAP') dnl
undefine(`CONT_POSITION') dnl
undefine(`DEVICE_DOMAIN_ID') dnl
undefine(`CONT_STACK_SIZE') dnl

define(`PCM_PERF_MODE', APM_SG_PERF_MODE_LOW_LATENCY) dnl'
define(`PCM_DIRECTION', APM_SUB_GRAPH_DIRECTION_RX) dnl'
define(`DEVICE_PERF_MODE', APM_SG_PERF_MODE_LOW_LATENCY) dnl'
define(`DEVICE_DIRECTION', APM_SUB_GRAPH_DIRECTION_TX) dnl'
define(`CONT_SENARIO_ID', APM_SUB_GRAPH_SID_AUDIO_PLAYBACK) dnl'
define(`CONT_CAP', `ifelse(LPASS_VER_COMPAT, 110000, APM_CONTAINER_TYPE_ID_GC, APM_CONTAINER_CAP_ID_EP)') dnl'
define(`CONT_POSITION', APM_CONT_GRAPH_POS_STREAM)dnl'
define(`DEVICE_DOMAIN_ID', APM_PROC_DOMAIN_ID_ADSP) dnl'
define(`CONT_STACK_SIZE', 8192) dnl'
dnl
define(`LOG_MODULE_IID', MOD_IID_START) dnl
define(`MFC_MODULE_IID', eval(MOD_IID_START + 1)) dnl
define(`SP_MODULE_IID', eval(MOD_IID_START + 2)) dnl
define(`CDC_DMA_MODULE_IID', eval(MOD_IID_START + 3)) dnl
define(`CONTROL_LINK_IID', eval(MOD_IID_START + 4)) dnl
define(`SG_INDEX', 1) dnl
define(`CONTAINER_INDEX', 1) dnl
define(`MOD_INDEX', 1) dnl
dnl
dnl DEVICE_PLAYBACK_ROUTE(stream-index, dai-id)
dnl
dnl The VI/TX chain lives in the WSA_CODEC_DMA_TX_0 (dai id 106 -> device106)
dnl subgraph. The "sp -> sp_vi" edge is a DAPM-only dependency: it has no
dnl data meaning (SP<->SP_VI exchange happens over the APM control link at
dnl 0x8001204), but it makes DAPM walk back from the active playback path
dnl into the capture chain so the TX BE DAI, codec_dma_tx, logger and
dnl sp_vi come up together with the RX side. If WSA_CODEC_DMA_TX_0 ever
dnl stops being 106 this edge and the control-link peer iid below must
dnl track it.
define(`DEVICE_PLAYBACK_ROUTE',
`'
`SectionGraph."NAME_PREFIX.$1 $2 Graph" {'
`        index STR($1)'
`        lines ['
`                "NAME_PREFIX.mfc$1, , $2 Audio Mixer"'
`                "NAME_PREFIX.sp$1, , NAME_PREFIX.mfc$1"'
`                "NAME_PREFIX.sp$1, , device106.sp_vi$1"'
`                "NAME_PREFIX.logger$1, , NAME_PREFIX.sp$1"'
`                "NAME_PREFIX.codec_dma_rx$1, , NAME_PREFIX.logger$1"'
`                "$2 Playback, , NAME_PREFIX.codec_dma_rx$1"'
`        ]'
`}')

# Depends on SP_VI_MODULE_IID (eval(0x00006190 + 1)) defined in other subgraph
dnl AR_CONTROL_LINK(index, iid, peer1-iid, peer1-port, peer2-iid, peer2-port, intent0, intent1, intent2, intent3)
AR_CONTROL_LINK(SG_INDEX, CONTROL_LINK_IID, eval(0x00006190 + 1), 0x80000000, SP_MODULE_IID, 0x80000000, 0x8001204, 0, 0, 0)

AR_SUBGRAPH_CONTROL_LINK(SG_INDEX, DEVICE_DAI_ID, SG_IID_START, DEVICE_PERF_MODE, DEVICE_DIRECTION, CONT_SENARIO_ID)

AR_CONTAINER(CONTAINER_INDEX, CONT_IID_START, CONT_CAP, CONT_STACK_SIZE, CONT_POSITION, DEVICE_DOMAIN_ID)
AR_MODULE_MFC(MOD_INDEX, SG_INDEX, CONTAINER_INDEX, MFC_MODULE_IID, 1, 1, 1, 2, SP_MODULE_IID)
AR_MODULE_SP_T14S(MOD_INDEX, SG_INDEX, CONTAINER_INDEX,   SP_MODULE_IID, 1, 1, 2, 1, 1, 2, LOG_MODULE_IID)
AR_MODULE_LOG(MOD_INDEX, SG_INDEX, CONTAINER_INDEX, 		LOG_MODULE_IID,     1, 1, 1, 2, 0x00001586, 1, 0, CDC_DMA_MODULE_IID)
AR_MODULE_CODEC_DMA_RX(MOD_INDEX, SG_INDEX, CONTAINER_INDEX, CDC_DMA_MODULE_IID, 1, 0, 1, 0, DEVICE_INTF_TYPE, DEVICE_INTF_INDEX, DEVICE_DATA_FORMAT, `DEVICE_NAME', NONE_IID)
DEVICE_PLAYBACK_ROUTE(MOD_INDEX, `DEVICE_NAME')
