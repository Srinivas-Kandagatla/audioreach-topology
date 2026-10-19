# Copyright, Linaro Ltd, 2025
# SPDX-License-Identifier: BSD-3-Clause
include(`audioreach/audioreach.m4') dnl
include(`util/pcm.m4') dnl
include(`audioreach/subgraph.m4') dnl
include(`audioreach/subgraph-control-link.m4') dnl
include(`audioreach/container.m4') dnl
include(`audioreach/control_link.m4') dnl
include(`audioreach/module_log.m4') dnl
include(`audioreach/module_codec_dma.m4') dnl
include(`audioreach/module_speaker_protection_vi_glymur.m4') dnl
include(`util/mixer.m4') dnl
dnl
#
# SubGraph for Device Backend
#
#             ___________________________
#             |   Sub Graph              |
# [KControl]->| [DEVICE-TX] <- [LOGGER]  |
#  Switch     |__________________________|
undefine(`CDC_DMA_MODULE_IID') dnl
undefine(`LOG_MODULE_IID') dnl
undefine(`SP_VI_MODULE_IID') dnl
undefine(`SG_INDEX') dnl
undefine(`CONTAINER_INDEX') dnl
undefine(`MOD_INDEX') dnl

undefine(`DEVICE_PERF_MODE') dnl
undefine(`DEVICE_DIRECTION') dnl
undefine(`CONT_SENARIO_ID') dnl
undefine(`CONT_CAP') dnl
undefine(`CONT_POSITION') dnl
undefine(`DEVICE_DOMAIN_ID') dnl
undefine(`CONT_STACK_SIZE') dnl
define(`DEVICE_PERF_MODE', APM_SG_PERF_MODE_LOW_LATENCY) dnl'
define(`DEVICE_DIRECTION', APM_SUB_GRAPH_DIRECTION_TX) dnl'
define(`CONT_SENARIO_ID', APM_SUB_GRAPH_SID_AUDIO_RECORD) dnl'
define(`CONT_CAP', `ifelse(LPASS_VER_COMPAT, 110000, APM_CONTAINER_TYPE_ID_GC, APM_CONTAINER_CAP_ID_EP)') dnl'
define(`CONT_POSITION', APM_CONT_GRAPH_POS_GLOBAL_DEV)dnl'
define(`DEVICE_DOMAIN_ID', APM_PROC_DOMAIN_ID_ADSP) dnl'
define(`CONT_STACK_SIZE', 8192) dnl'

define(`CDC_DMA_MODULE_IID', MOD_IID_START) dnl
define(`SP_VI_MODULE_IID', eval(MOD_IID_START + 1)) dnl
define(`LOG_MODULE_IID', eval(MOD_IID_START + 2)) dnl
define(`CONTROL_LINK_IID', eval(MOD_IID_START + 3)) dnl
define(`SG_INDEX', 1) dnl
define(`CONTAINER_INDEX', 1) dnl
define(`MOD_INDEX', 1) dnl
dnl
dnl DEVICE_CAPTURE_SP_VI_ROUTE(stream-index, dai-id)
define(`DEVICE_CAPTURE_SP_VI_ROUTE',
`'
`SectionGraph."NAME_PREFIX.$1 $2 Graph" {'
`        index STR($1)'
`        lines ['
`               "NAME_PREFIX.codec_dma_tx$1, , $2 Capture"'
`               "NAME_PREFIX.logger$1, , NAME_PREFIX.codec_dma_tx$1"'
`               "NAME_PREFIX.sp_vi$1, , NAME_PREFIX.logger$1"'
`        ]'
`}')

# Depends on SP_MODULE_IID defined in other subgraph
dnl AR_CONTROL_LINK(index, iid, peer1-iid, peer1-port, peer2-iid, peer2-port, intent0, intent1, intent2, intent3)
AR_CONTROL_LINK(SG_INDEX, CONTROL_LINK_IID, SP_VI_MODULE_IID, 0x80000000, SP_MODULE_IID, 0x80000000, 0x8001204, 0, 0, 0)

dnl Advertise this (VI capture) subgraph under the WSA RX side's DAI id so
dnl the kernel groups both subgraphs into graph_info[105]. A single MM1
dnl playback-time GRAPH_OPEN then carries RX+TX+control-link together.
dnl The subgraph still owns its own module/widget namespace via
dnl NAME_PREFIX = device106 (set by DEVICE_SG_ADD).
dnl
dnl Because dai-index ($2) != DEVICE_DAI_ID, AR_SUBGRAPH_CONTROL_LINK
dnl auto-emits AR_TKN_U32_SUB_GRAPH_SAMPLE_RATE / BIT_WIDTH /
dnl NUM_CHANNELS from the DEVICE_FORMAT / DEVICE_MAX_RATE /
dnl DEVICE_MAX_CHANNELS values the enclosing DEVICE_SG_ADD declared
dnl (S32_LE, 8000, 4 for this subgraph). The kernel's
dnl audioreach_set_media_format uses that in place of the opener's
dnl 48kHz/S16_LE cfg when configuring the TX CODEC_DMA + SP_VI modules.
AR_SUBGRAPH_CONTROL_LINK(SG_INDEX, WSA_CODEC_DMA_RX_0, SG_IID_START,
			 DEVICE_PERF_MODE, DEVICE_DIRECTION, CONT_SENARIO_ID)

AR_CONTAINER(CONTAINER_INDEX, CONT_IID_START, CONT_CAP, CONT_STACK_SIZE, CONT_POSITION, DEVICE_DOMAIN_ID)

AR_MODULE_CODEC_DMA_TX(MOD_INDEX, SG_INDEX, CONTAINER_INDEX, CDC_DMA_MODULE_IID, 0, 1, 1, 2, DEVICE_INTF_TYPE, DEVICE_INTF_INDEX, DEVICE_DATA_FORMAT, `DEVICE_NAME', LOG_MODULE_IID)
AR_MODULE_LOG(MOD_INDEX, SG_INDEX, CONTAINER_INDEX, LOG_MODULE_IID, 1, 1, 1, 2, 0x00001586, 1, 0, SP_VI_MODULE_IID)
AR_MODULE_SP_VI_GLYMUR(MOD_INDEX, SG_INDEX, CONTAINER_INDEX, SP_VI_MODULE_IID, 1, 1, 4, 1, 1, 2, NONE_IID)
dnl No DEVICE_CAPTURE_MIXER here: no userspace capture PCM for VI. The
dnl VI subgraph is co-opened through DAI_INDEX=105 sharing (see the
dnl AR_SUBGRAPH_CONTROL_LINK call above) and its codec DAIs are driven
dnl via the WSA Playback BE's multi_direction_codecs flag.
DEVICE_CAPTURE_SP_VI_ROUTE(MOD_INDEX, `DEVICE_NAME')
