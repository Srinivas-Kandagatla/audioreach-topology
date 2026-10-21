# SPDX-License-Identifier: BSD-3-Clause
# Copyright, Linaro Ltd, 2025
include(`audioreach/audioreach.m4')
include(`audioreach/stream-subgraph.m4')
include(`audioreach/device-subgraph.m4')
include(`util/route.m4')
include(`util/mixer.m4')
include(`audioreach/tokens.m4')
#
# Stream SubGraph for MultiMedia Playback
#
#  ______________________________________________
# |               Sub Graph 1                    |
# | [WR_SH] -> [PCM DEC] -> [PCM CONV] -> [LOG]  |- Kcontrol
# |______________________________________________|
#
dnl Playback MultiMedia1 (2 speakers: left/right)
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-vol-playback.m4, FRONTEND_DAI_MULTIMEDIA1,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004001, 0x00004001, 0x00006001, `110000')
dnl Capture MultiMedia2
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-capture.m4, FRONTEND_DAI_MULTIMEDIA2,
	`S32_LE', 8000, 48000, 1, 2,
	0x00004003, 0x00004003, 0x00006020, `110000')
#
#
# Device SubGraph for WSA RX0 Backend
#
#         ___________________
#        |   Sub Graph 2     |
# Mixer -| [LOG] -> [WSA EP] |
#        |___________________|
#
dnl DEVICE_SG_ADD(stream, stream-dai-id, stream-index,
dnl 	format, min-rate, max-rate, min-channels, max-channels,
dnl	interface-type, interface-index, data-format,
dnl	sg-iid-start, cont-iid-start, mod-iid-start)
dnl
dnl WSA Playback (speaker protection, 2 speakers). Reuses the glymur
dnl 4-speaker SP modules; the DSP only drives the two slots the hardware
dnl exposes, the other two stay inert.
DEVICE_SG_ADD(audioreach/subgraph-device-codec-sp-dma-playback-glymur.m4, `WSA_CODEC_DMA_RX_0', WSA_CODEC_DMA_RX_0,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_WSA, CODEC_INTF_IDX_RX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004005, 0x00004005, 0x00006050)
dnl
dnl WSA VI Capture (SP_VI). Folded into graph_info[WSA_CODEC_DMA_RX_0]
dnl so a single MM1 playback-time GRAPH_OPEN carries both the RX and VI
dnl subgraphs. VI runs at 8 kHz / S32_LE; the glymur SP_VI subgraph
dnl file carries the fold+static-format wiring via AR_TKN_DAI_INDEX =
dnl WSA_CODEC_DMA_RX_0.
DEVICE_SG_ADD(audioreach/subgraph-device-codec-sp-vi-dma-capture-glymur.m4, `WSA_CODEC_DMA_TX_0', WSA_CODEC_DMA_TX_0,
	`S32_LE', 8000, 8000, 1, 2,
	LPAIF_INTF_TYPE_WSA, CODEC_INTF_IDX_TX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004019, 0x00004019, 0x00006190)
dnl
dnl VA Capture
DEVICE_SG_ADD(audioreach/subgraph-device-codec-dma-capture.m4, `VA_CODEC_DMA_TX_0', VA_CODEC_DMA_TX_0,
	`S16_LE', 48000, 48000, 1, 4,
	LPAIF_INTF_TYPE_VA, CODEC_INTF_IDX_TX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004018, 0x00004018, 0x00006180)
dnl

STREAM_DEVICE_PLAYBACK_MIXER(WSA_CODEC_DMA_RX_0, ``WSA_CODEC_DMA_RX_0'', ``MultiMedia1'')

STREAM_DEVICE_PLAYBACK_ROUTE(WSA_CODEC_DMA_RX_0, ``WSA_CODEC_DMA_RX_0 Audio Mixer'', ``MultiMedia1, stream0.logger1'')

SPEAKER_PROTECTION_OPERATION_MODE_CTRL()
SPEAKER_PROTECTION_R0T0_CTRL()

dnl MM2 only exposes the VA capture; WSA VI capture is no longer a
dnl userspace source. The VI subgraph is co-opened via DAI_INDEX=105
dnl sharing with the WSA playback graph (see
dnl audioreach/subgraph-device-codec-sp-vi-dma-capture-glymur.m4) and
dnl its codec DAIs ride on the WSA Playback BE as mixed-direction
dnl codec DAIs (snd_soc_dai_link::multi_direction_codecs on the kernel
dnl side).
STREAM_DEVICE_CAPTURE_MIXER(FRONTEND_DAI_MULTIMEDIA2, ``VA_CODEC_DMA_TX_0'')
dnl STREAM_DEVICE_CAPTURE_ROUTE(stream-index, mixer-name, route1, route2.. routeN)
STREAM_DEVICE_CAPTURE_ROUTE(FRONTEND_DAI_MULTIMEDIA2, ``MultiMedia2 Mixer'', ``VA_CODEC_DMA_TX_0, device110.logger1'')
