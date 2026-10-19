# Copyright, Linaro Ltd, 2023
# SPDX-License-Identifier: BSD-3-Clause
define(`STR', `"'$1`"') dnl
dnl FMT_BIT_WIDTH(fmt): bit width implied by an ALSA PCM format name.
dnl Covers the signed little-endian formats the AudioReach topology
dnl uses in practice; extend as needed.
define(`FMT_BIT_WIDTH',
`ifelse($1, `S16_LE', `16',
        $1, `S24_LE', `24',
        $1, `S24_3LE', `24',
        $1, `S32_LE', `32',
        `0')') dnl
