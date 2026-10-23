# SPDX-License-Identifier: BSD-3-Clause
# Lenovo ThinkPad T14s Gen 7 (Snapdragon X2 Elite / Mahua, Lenovo 22A7/22A8):
# 2x WSA8845 speakers (speaker protection enabled), 2x DMIC, WCD headphone
# jack (RX_CODEC_DMA_RX_0) and headset mic (TX_CODEC_DMA_TX_3), plus two
# DisplayPort sinks (DP0, DP1).
# Based on GLYMUR-CRD.m4
# Copyright, Linaro Ltd, 2023
#
# On-board HDMI (DISPLAY_PORT_RX_2 via RTD2171A) is intentionally not wired
# here yet.
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
dnl Playback MultiMedia1 - Speakers
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-vol-playback.m4, FRONTEND_DAI_MULTIMEDIA1,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004001, 0x00004001, 0x00006001, `110000')
dnl Capture MultiMedia2 - DMIC
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-capture.m4, FRONTEND_DAI_MULTIMEDIA2,
	`S16_LE', 48000, 48000, 1, 2,
	0x00004003, 0x00004003, 0x00006020, `110000')
dnl Playback MultiMedia3 - DP0
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-vol-playback.m4, FRONTEND_DAI_MULTIMEDIA3,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004002, 0x00004002, 0x00006030, `110000')
dnl Playback MultiMedia4 - DP1
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-vol-playback.m4, FRONTEND_DAI_MULTIMEDIA4,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004004, 0x00004004, 0x00006040, `110000')
dnl Playback MultiMedia5 - Headphones
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-vol-playback.m4, FRONTEND_DAI_MULTIMEDIA5,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004009, 0x00004009, 0x00006090, `110000')
dnl Capture MultiMedia6 - Headset mic
STREAM_SG_PCM_ADD(audioreach/subgraph-stream-capture.m4, FRONTEND_DAI_MULTIMEDIA6,
	`S16_LE', 48000, 48000, 1, 2,
	0x00004010, 0x00004010, 0x00006100, `110000')
#
# Device SubGraph for WSA RX0 Backend
#
#         ___________________
#        |   Sub Graph 2     |
# Mixer -| [LOG] -> [WSA EP] |
#        |___________________|
#
dnl DEVICE_SG_ADD(stream, stream-dai-id, stream-index,
dnl	format, min-rate, max-rate, min-channels, max-channels,
dnl	interface-type, interface-index, data-format,
dnl	sg-iid-start, cont-iid-start, mod-iid-start
dnl WSA Playback (speaker protection, 2 speakers). Uses the T14s-specific
dnl SP module cfg (2-speaker static+dynamic VI blob and per-speaker
dnl electrical params for the T14s WSA8845 pair).
DEVICE_SG_ADD(audioreach/subgraph-device-codec-sp-dma-playback-t14s.m4, `WSA_CODEC_DMA_RX_0', WSA_CODEC_DMA_RX_0,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_WSA, CODEC_INTF_IDX_RX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004005, 0x00004005, 0x00006050)
dnl
dnl WSA VI Capture (SP_VI, 2 speakers). Folded into
dnl graph_info[WSA_CODEC_DMA_RX_0] so a single MM1 playback-time
dnl GRAPH_OPEN carries both the RX and VI subgraphs. VI runs at
dnl 8 kHz / S32_LE; the T14s SP_VI subgraph file carries the
dnl fold+static-format wiring via AR_TKN_DAI_INDEX = WSA_CODEC_DMA_RX_0.
DEVICE_SG_ADD(audioreach/subgraph-device-codec-sp-vi-dma-capture-t14s.m4, `WSA_CODEC_DMA_TX_0', WSA_CODEC_DMA_TX_0,
	`S32_LE', 8000, 8000, 1, 2,
	LPAIF_INTF_TYPE_WSA, CODEC_INTF_IDX_TX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004019, 0x00004019, 0x00006190)
dnl
dnl WCDRX Headphone Playback
DEVICE_SG_ADD(audioreach/subgraph-device-codec-dma-playback.m4, `RX_CODEC_DMA_RX_0', RX_CODEC_DMA_RX_0,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_RXTX, CODEC_INTF_IDX_RX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004011, 0x00004011, 0x00006110)
dnl
dnl Display port0 Playback
DEVICE_SG_ADD(audioreach/subgraph-device-display-port-playback.m4, `DISPLAY_PORT_RX_0', DISPLAY_PORT_RX_0,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_LPAIF, 0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004006, 0x00004006, 0x00006060, `DISPLAY_PORT_RX_0')
dnl
dnl Display port1 Playback
DEVICE_SG_ADD(audioreach/subgraph-device-display-port-playback.m4, `DISPLAY_PORT_RX_1', DISPLAY_PORT_RX_1,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_LPAIF, 0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004007, 0x00004007, 0x00006070, `DISPLAY_PORT_RX_1')
dnl

dnl VA Capture
DEVICE_SG_ADD(audioreach/subgraph-device-codec-dma-capture.m4, `VA_CODEC_DMA_TX_0', VA_CODEC_DMA_TX_0,
	`S32_LE', 48000, 48000, 1, 2,
	LPAIF_INTF_TYPE_VA, CODEC_INTF_IDX_TX0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004018, 0x00004018, 0x00006180)
dnl
dnl WCDTX Headset Mic Capture
DEVICE_SG_ADD(audioreach/subgraph-device-codec-dma-capture.m4, `TX_CODEC_DMA_TX_3', TX_CODEC_DMA_TX_3,
	`S16_LE', 48000, 48000, 1, 2,
	LPAIF_INTF_TYPE_RXTX, CODEC_INTF_IDX_TX3, 0, DATA_FORMAT_FIXED_POINT,
	0x00004012, 0x00004012, 0x00006120)
dnl

STREAM_DEVICE_PLAYBACK_MIXER(WSA_CODEC_DMA_RX_0, ``WSA_CODEC_DMA_RX_0'', ``MultiMedia1'', ``MultiMedia3'', ``MultiMedia4'', ``MultiMedia5'' )
STREAM_DEVICE_PLAYBACK_MIXER(RX_CODEC_DMA_RX_0, ``RX_CODEC_DMA_RX_0'', ``MultiMedia1'', ``MultiMedia3'', ``MultiMedia4'', ``MultiMedia5'' )
STREAM_DEVICE_PLAYBACK_MIXER(DISPLAY_PORT_RX_0, ``DISPLAY_PORT_RX_0'', ``MultiMedia1'', ``MultiMedia3'', ``MultiMedia4'', ``MultiMedia5'' )
STREAM_DEVICE_PLAYBACK_MIXER(DISPLAY_PORT_RX_1, ``DISPLAY_PORT_RX_1'', ``MultiMedia1'', ``MultiMedia3'', ``MultiMedia4'', ``MultiMedia5'' )

STREAM_DEVICE_PLAYBACK_ROUTE(WSA_CODEC_DMA_RX_0, ``WSA_CODEC_DMA_RX_0 Audio Mixer'', ``MultiMedia1, stream0.logger1'', ``MultiMedia3, stream2.logger1'', ``MultiMedia4, stream3.logger1'', ``MultiMedia5, stream4.logger1'')
STREAM_DEVICE_PLAYBACK_ROUTE(RX_CODEC_DMA_RX_0, ``RX_CODEC_DMA_RX_0 Audio Mixer'', ``MultiMedia1, stream0.logger1'', ``MultiMedia3, stream2.logger1'', ``MultiMedia4, stream3.logger1'', ``MultiMedia5, stream4.logger1'')
STREAM_DEVICE_PLAYBACK_ROUTE(DISPLAY_PORT_RX_0, ``DISPLAY_PORT_RX_0 Audio Mixer'', ``MultiMedia1, stream0.logger1'', ``MultiMedia3, stream2.logger1'', ``MultiMedia4, stream3.logger1'', ``MultiMedia5, stream4.logger1'')
STREAM_DEVICE_PLAYBACK_ROUTE(DISPLAY_PORT_RX_1, ``DISPLAY_PORT_RX_1 Audio Mixer'', ``MultiMedia1, stream0.logger1'', ``MultiMedia3, stream2.logger1'', ``MultiMedia4, stream3.logger1'', ``MultiMedia5, stream4.logger1'')

SPEAKER_PROTECTION_OPERATION_MODE_CTRL()
SPEAKER_PROTECTION_R0T0_CTRL()

dnl STREAM_DEVICE_CAPTURE_MIXER(stream-index, kcontrol1, kcontrol2... kcontrolN)
dnl
dnl WSA VI capture is not a userspace source; the VI subgraph is
dnl co-opened via DAI_INDEX=105 sharing with the WSA playback graph
dnl (see audioreach/subgraph-device-codec-sp-vi-dma-capture-glymur.m4)
dnl and its codec DAIs ride on the WSA Playback BE as mixed-direction
dnl codec DAIs (snd_soc_dai_link::multi_direction_codecs on the kernel
dnl side).
STREAM_DEVICE_CAPTURE_MIXER(FRONTEND_DAI_MULTIMEDIA2, ``VA_CODEC_DMA_TX_0'')
STREAM_DEVICE_CAPTURE_MIXER(FRONTEND_DAI_MULTIMEDIA6, ``TX_CODEC_DMA_TX_3'')
dnl STREAM_DEVICE_CAPTURE_ROUTE(stream-index, mixer-name, route1, route2.. routeN)
STREAM_DEVICE_CAPTURE_ROUTE(FRONTEND_DAI_MULTIMEDIA2, ``MultiMedia2 Mixer'', ``VA_CODEC_DMA_TX_0, device110.logger1'')
STREAM_DEVICE_CAPTURE_ROUTE(FRONTEND_DAI_MULTIMEDIA6, ``MultiMedia6 Mixer'', ``TX_CODEC_DMA_TX_3, device120.logger1'')
