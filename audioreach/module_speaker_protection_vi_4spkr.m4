# Copyright, Linaro Ltd, 2025
# SPDX-License-Identifier: BSD-3-Clause
include(`util/util.m4') dnl
dnl AR_MODULE_SP_VI_4SPKR(index, sgidx, container-idx, iid, maxip-ports, max-op-ports, in-ports, out-ports, src-port, dst-port, dst-iid)
dnl
dnl glymur-crd (WSA8845 / wsa884x) speaker protection VI cfg blob.
dnl
dnl The sp_vi$1_cfg_data words are, in order:
dnl   words 0-3  struct audioreach_module_priv_data wrapper -- size of the
dnl              record stream (total - 16), then SND_SOC_AR_TPLG_MODULE_CFG_TYPE
dnl              (0x01001006), then two reserved words. Not a param record.
dnl   words 4+   nine apm_module_param_data records, back to back, sorted by
dnl              ascending param_id. Each is a 16 byte header (module_instance_id,
dnl              param_id, param_size, error_code) followed by param_size bytes
dnl              of payload. Records here are packed with no inter-record
dnl              padding; the driver re-emits each payload padded up to 8 bytes
dnl              before sending, because that is what the DSP's record walker
dnl              assumes (see audioreach_speaker_protection_pack_record()).
dnl
dnl The records' module_instance_id is SP_VI_IID_HEX, which expands to the iid
dnl passed in as $4 (0x6191 here, SP_VI_MODULE_IID = MOD_IID_START + 1)
dnl formatted as eight hex digits, the same scheme
dnl module_speaker_protection_4spkr.m4 uses for the SP module. An earlier
dnl revision of the kernel built the dynamic cfg param in C and sent it at
dnl graph open (audioreach_sp_vi_set_dynamic_cfg(), with a 0x00004032
dnl placeholder iid patched at runtime); both are gone, so the blob has to be
dnl complete and correctly addressed here.
dnl
dnl The nine records, in blob order, with the sp_v5 VI library struct each
dnl payload has to match (spm/pp/sp_v5/api/sp_vi_v5.h unless noted). glymur's
dnl VI module is MODULE_ID_SPEAKER_PROTECTION_V5_VI (0x070010E3), served by
dnl capi_viv5 per build/glymur/pp_libs_cfg.json, so sp_v5 is the authority --
dnl not sp_v7, which is STATIC_NO_BUILD on this target. Every one of these is
dnl handled by a case in capi_viv5's set_param switch (capi_vi_v5.cpp):
dnl
dnl   0x08001026 PARAM_ID_MODULE_ENABLE              4 B  param_id_module_enable_t
dnl   0x080010A6 PARAM_ID_RTM_LOGGING_ENABLE          8 B  rtm_logging_enable_payload_t
dnl   0x080011C2 PARAM_ID_VI_OUTPUT_SPLIT_ENABLE      4 B  param_id_vi_output_bps_split_enable_t
dnl   0x080011F6 PARAM_ID_SP_VI_STATIC_CFG           44 B  param_id_sp_vi_static_cfg_t
dnl   0x08001203 PARAM_ID_SP_VI_CHANNEL_MAP_CFG      36 B  param_id_sp_vi_channel_map_cfg_t
dnl   0x08001364 PARAM_ID_SP_VI_CFSMOOTHING_CFG_PARAM 12 B param_id_sp_ex_vi_CFSmoothing_param_t
dnl   0x08001384 PARAM_ID_SPv5_EX_VI_DYNAMIC_CFG   2084 B  param_id_sp_ex_vi_dynamic_cfg_t
dnl   0x08001510 PARAM_ID_MAX_RATED_TEMP             20 B  param_id_max_rated_temp_param_t
dnl   0x08001535 PARAM_ID_SPV5_TH_VI_DYNAMIC_CFG    212 B  param_id_sp_th_vi_dynamic_cfg_t
dnl
dnl Two params present in the source calibration dump are deliberately NOT in
dnl the blob, because capi_viv5 on this firmware cannot accept them:
dnl   PARAM_ID_SPV5_VI_NEGATIVE_DC_COMP_ENABLE -- no such param id is defined
dnl     anywhere in the ADSP source. The only negative-DC field that exists is
dnl     negative_DC_comp_en, a member of sp_v7's per-speaker EX struct
dnl     (spm/pp/sp_v7/api/sp_vi_v7.h), reachable only through sp_v7's own EX
dnl     dynamic cfg. sp_v5's sp_vi_ex_spkr_param_t has no equivalent field and
dnl     capi_viv5 has no case for it, so sending it would be rejected.
dnl   PARAM_ID_SPV5_EX_VI_DYNAMIC_CFG_V2 -- included, but under its real id.
dnl     The dump's "_V2" name has no definition in the ADSP source; its payload
dnl     is a field for field match of sp_v5's PARAM_ID_SPv5_EX_VI_DYNAMIC_CFG
dnl     (0x08001384): num_ch then num_ch x sp_vi_ex_spkr_param_t, the latter
dnl     being 37 32-bit scalars plus three fbsp_tdf_2_cfg_t filter blocks
dnl     (numCh, stages, num[15], den[10], numQ[5], denQ[5] = 124 B each), so
dnl     4 + 4 x 520 = 2084 B, which is exactly what the dump's 593 fields pack
dnl     into. So it is emitted as 0x08001384.
dnl
dnl Sizes matter twice over. capi_viv5 rejects a short payload outright
dnl (fbsp_vi_set_size_check(), FBSP_EX_VI_DYNAMIC_PARAM expects
dnl sizeof(fbsp_ex_vi_dynamic_param_t) + num_ch * sizeof(fbsp_ex_spkr_param_t)),
dnl and both the TH and EX dynamic cfg cases additionally fail the set if
dnl num_ch does not equal the num_speakers the static cfg established -- 4
dnl here. PARAM_ID_SP_VI_CHANNEL_MAP_CFG is the exception: its num_ch is 8,
dnl CHANNELS_PER_SPKR (2, a V/I pair) x 4 speakers, which is what capi_viv5
dnl checks it against once media format arrives.
dnl
dnl The driver sends the blob as chunks of whole records, budgeted to 512 bytes
dnl but never splitting a record, so the record sizes above become packets of
dnl 224, 2104 and 272 bytes. All three clear the largest packet this transport
dnl has been observed to accept (2244 bytes); rpmsg_trysend() cannot grow the
dnl DSP's RX intents, so an oversized chunk fails with -EBUSY having never been
dnl sent. The 2084 byte EX record is the one to watch if that ceiling ever
dnl drops -- it is a single record and therefore cannot be split further.
dnl
dnl Per-speaker electrical parameters are in the VI channel order the kernel's
dnl channel map sets up: speakers 0 and 1 are the left woofer and tweeter, 2
dnl and 3 the right pair. Measured per device, so the conversion factors and
dnl backup calibration points differ slightly per channel. Without them the VI
dnl module uses generic defaults whose pilot tone thresholds the WSA8845 sense
dnl levels sit right on, so calibration oscillates IN_PROGRESS <-> LOW_VI and
dnl times out with R0 still zero.
dnl
dnl The calibration budget (last 5 words of each vi_r0t0_cali_param) is
dnl identical for all four speakers: wait_time_ms 100, cali_time_ms 2000,
dnl vi_wait_time_ms 100, r0_und_est_fac_q16 0, r0_rng_fac_q10 0x0600 (1.5),
dnl t0_min_q6 0 (0 degC), t0_max_q6 0x0c80 (50 degC). vi_wait_time_ms is the
dnl 100 ms the calibration data asks for; if calibration starts latching
dnl VI_WAIT_TIMEOUT before the pilot tone has ramped up, raise it towards the
dnl DSP's own 2000 ms default.
define(`AR_MODULE_SP_VI_4SPKR',
`'dnl
dnl The blob's records carry the instance id as a bare hex word, so format $4
dnl (a decimal iid from eval()) as eight hex digits.
`pushdef(`SP_VI_IID_HEX', `'eval($4,16,8))'dnl
`'
`SectionVendorTuples."NAME_PREFIX.sp_vi$1_tuples" {'
`        tokens "audioreach_tokens"'
`'
`        tuples."word.u32_data" {'
`                AR_TKN_U32_MODULE_INSTANCE_ID STR($4)'
`                AR_TKN_U32_MODULE_ID STR(MODULE_ID_SPEAKER_PROTECTION_VI)'
`                AR_TKN_U32_MODULE_MAX_IP_PORTS STR($5)'
`                AR_TKN_U32_MODULE_MAX_OP_PORTS STR($6)'
`                AR_TKN_U32_MODULE_IN_PORTS STR($7)'
`                AR_TKN_U32_MODULE_OUT_PORTS STR($8)'
`                AR_TKN_U32_MODULE_SRC_OP_PORT_ID STR($9)'
`                AR_TKN_U32_MODULE_DST_IN_PORT_ID STR($10)'
`                AR_TKN_U32_MODULE_SRC_INSTANCE_ID STR($4)'
`                AR_TKN_U32_MODULE_DST_INSTANCE_ID STR($11)'
`        }'
`}'
`'
`SectionData."NAME_PREFIX.sp_vi$1_data" {'
`        tuples "NAME_PREFIX.sp_vi$1_tuples"'
`}'
`'
`SectionData."NAME_PREFIX.sp_vi$1_cfg_data" {'
`        words "0x00000a08,0x01001006,0x00000000,0x00000000,'
`               0x`'SP_VI_IID_HEX,0x08001026,0x00000004,0x00000000,'
`               0x00000001,0x`'SP_VI_IID_HEX,0x080010a6,0x00000008,'
`               0x00000000,0x00000001,0x0000184b,0x`'SP_VI_IID_HEX,'
`               0x080011c2,0x00000004,0x00000000,0x00000000,'
`               0x`'SP_VI_IID_HEX,0x080011f6,0x0000002c,0x00000000,'
`               0x00000004,0x00001f40,0x00000028,0x000003e8,'
`               0x00000001,0x00000000,0x00000000,0x00000008,'
`               0x00000000,0x00000000,0x000000c8,0x`'SP_VI_IID_HEX,'
`               0x08001203,0x00000024,0x00000000,0x00000008,'
`               0x00000001,0x00000002,0x00000003,0x00000004,'
`               0x00000005,0x00000006,0x00000007,0x00000008,'
`               0x`'SP_VI_IID_HEX,0x08001364,0x0000000c,0x00000000,'
`               0x00000000,0x08000000,0x18000000,0x`'SP_VI_IID_HEX,'
`               0x08001384,0x00000824,0x00000000,0x00000004,'
`               0x044e147b,0x000dd2f2,0x00000000,0x00000000,'
`               0x019e76c9,0x009645a2,0x00733333,0x04b5c28f,'
`               0x1b62e148,0x03000000,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x019e76c9,0x000007d0,0x000007d0,0x0000068e,'
`               0x00000002,0x00000000,0x0000068e,0x0000000a,'
`               0x00000190,0x0af5c28f,0x0f10e560,0x07028f5c,'
`               0x00178d50,0x002a3d71,0x000001f4,0x000001f4,'
`               0x00000000,0x00010001,0x265b67f0,0x4cb6cfe1,'
`               0x265b67f0,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x8cf8b002,0x343a2b3e,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x0000fffa,'
`               0x00000000,0x00010000,0x00000000,0x00000000,'
`               0x00010001,0x3f690d29,0x812de5af,0x3f690d29,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x812f49b7,0x3ed37e59,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000001,0x00000000,'
`               0x00010000,0x00000000,0x00000000,0x00010001,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x40000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00010000,'
`               0x00000000,0x00000000,0x03b020c5,0x0003d70a,'
`               0x0001eb85,0x000b020c,0x00916873,0x00239581,'
`               0x004b851f,0x0363d70a,0x3019c28f,0x03000000,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x00916873,0x000007d0,'
`               0x000007d0,0x0000068e,0x00000002,0x000007d0,'
`               0x0000068e,0x0000000a,0x00000190,0x0b0a3d71,'
`               0x0f2c0831,0x070d4fdf,0x0029ba5e,0x00326e98,'
`               0x000001f4,0x000001f4,0x00000000,0x00010001,'
`               0x227f69e8,0x44fed3d0,0x227f69e8,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x88924d09,'
`               0x37f7b09f,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x0000fff9,0x00000000,0x00010000,'
`               0x00000000,0x00000000,0x00010001,0x3f690d29,'
`               0x812de5af,0x3f690d29,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x812f49b7,0x3ed37e59,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000001,0x00000000,0x00010000,0x00000000,'
`               0x00000000,0x00010001,0x63f31833,0xf6a75d0d,'
`               0xa5658abf,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x590eae52,0x190eae52,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000002,'
`               0x00000000,0x00010000,0x00000000,0x00000000,'
`               0x0452f1aa,0x000dd2f2,0x00000000,0x00000000,'
`               0x019e76c9,0x009645a2,0x007c6a7f,0x044fdf3b,'
`               0x1a78cccd,0x03000000,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x019e76c9,0x000007d0,0x000007d0,0x0000068e,'
`               0x00000002,0x00000000,0x0000068e,0x0000000a,'
`               0x00000190,0x0ae3d70a,0x0f245a1d,0x0704dd2f,'
`               0x00245a1d,0x00272b02,0x000001f4,0x000001f4,'
`               0x00000000,0x00010001,0x265b67f0,0x4cb6cfe1,'
`               0x265b67f0,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x8cf8b002,0x343a2b3e,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x0000fffa,'
`               0x00000000,0x00010000,0x00000000,0x00000000,'
`               0x00010001,0x3f690d29,0x812de5af,0x3f690d29,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x812f49b7,0x3ed37e59,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000001,0x00000000,'
`               0x00010000,0x00000000,0x00000000,0x00010001,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x40000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00010000,'
`               0x00000000,0x00000000,0x03981062,0x0003d70a,'
`               0x00018937,0x0007ae14,0x00916873,0x00239581,'
`               0x0032f1aa,0x03a6e979,0x32d47ae1,0x03000000,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x000007d0,0x000007d0,'
`               0x000007d0,0x000007d0,0x00916873,0x000007d0,'
`               0x000007d0,0x0000068e,0x00000002,0x00000000,'
`               0x0000068e,0x0000000a,0x00000190,0x0b0f5c29,'
`               0x0f276c8b,0x0707ae14,0x0022d0e5,0x0026e979,'
`               0x000001f4,0x000001f4,0x00000000,0x00010001,'
`               0x227f69e8,0x44fed3d0,0x227f69e8,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x88924d09,'
`               0x37f7b09f,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x0000fff9,0x00000000,0x00010000,'
`               0x00000000,0x00000000,0x00010001,0x3f690d29,'
`               0x812de5af,0x3f690d29,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x812f49b7,0x3ed37e59,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000001,0x00000000,0x00010000,0x00000000,'
`               0x00000000,0x00010001,0x63f31833,0xf6a75d0d,'
`               0xa5658abf,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x590eae52,0x190eae52,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000000,'
`               0x00000000,0x00000000,0x00000000,0x00000002,'
`               0x00000000,0x00010000,0x00000000,0x00000000,'
`               0x`'SP_VI_IID_HEX,0x08001510,0x00000014,0x00000000,'
`               0x00000004,0x00001900,0x00001900,0x00001900,'
`               0x00001900,0x`'SP_VI_IID_HEX,0x08001535,0x000000d4,'
`               0x00000000,0x00000004,0x044e978d,0x00000a3d,'
`               0x00178d50,0x0800044e,0x7f3a2ae6,0x09224286,'
`               0x37847917,0x00004000,0x03b0624d,0x00000a3d,'
`               0x0029ba5e,0x080003b0,0x7f3a2c55,0x08bd4286,'
`               0x37187a44,0x00004000,0x0453b645,0x00000a3d,'
`               0x00245a1d,0x08000453,0x7f3a2bc7,0x079a4286,'
`               0x37017976,0x00004000,0x0398d4fd,0x00000a3d,'
`               0x0022d0e5,0x08000398,0x7f3a2bea,0x08204286,'
`               0x382d7a35,0x00004000,0x00000064,0x000007d0,'
`               0x00000064,0x06000000,0x0c800000,0x00000064,'
`               0x000007d0,0x00000064,0x06000000,0x0c800000,'
`               0x00000064,0x000007d0,0x00000064,0x06000000,'
`               0x0c800000,0x00000064,0x000007d0,0x00000064,'
`               0x06000000,0x0c800000"'
`}'
`'
`SectionWidget."NAME_PREFIX.sp_vi$1" {'
`        index STR($1)'
`        type "src"'
`        no_pm "true"'
`        subseq "10"'
`        data ['
`                "NAME_PREFIX.sub_graph$2_data"'
`                "NAME_PREFIX.container$3_data"'
`                "NAME_PREFIX.sp_vi$1_data"'
`                "NAME_PREFIX.sp_vi$1_cfg_data"'
`        ]'
`}'dnl
`popdef(`SP_VI_IID_HEX')') dnl
