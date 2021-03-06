@
@ Copyright (c) 2013 The WebRTC project authors. All Rights Reserved.
@
@ Use of this source code is governed by a BSD-style license
@ that can be found in the LICENSE file in the root of the source
@ tree. An additional intellectual property rights grant can be found
@ in the file PATENTS.  All contributing project authors may
@ be found in the AUTHORS file in the root of the source tree.
@
@ Some code in this file was originally from file
@ omxSP_FFTInv_CToC_SC16_Sfs_s.S which was licensed as follows.
@ It has been relicensed with permission from the copyright holders.
@

@
@ File Name:  omxSP_FFTInv_CToC_SC16_Sfs_s.s
@ OpenMAX DL: v1.0.2
@ Last Modified Revision:   6729
@ Last Modified Date:       Tue, 17 Jul 2007
@
@ (c) Copyright 2007-2008 ARM Limited. All Rights Reserved.
@

@
@ Description:
@ Compute an inverse FFT for a 16-bit real signal, with complex FFT routines.
@

#include "dl/api/arm/armCOMM_s.h"
#include "dl/api/arm/omxtypes_s.h"

.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix2_fs_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix2_fs_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix4_fs_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix4_ls_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix8_fs_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix4_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix4_fs_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix4_ls_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix8_fs_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix4_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix2_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix2_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix2_ls_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix2_ls_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Radix2_ps_OutOfPlace_unsafe
.extern  armSP_FFTInv_CToC_SC16_Sfs_Radix2_ps_OutOfPlace_unsafe

@Input Registers
#define pSrc            r0
#define pDst            r1
#define pFFTSpec        r2
#define scale           r3

@ Output registers
#define result  r0

@Local Scratch Registers
#define argTwiddle      r1
#define argDst          r2
#define argScale        r4
#define pTwiddle        r4
#define tmpOrder        r4
#define pOut            r5
#define subFFTSize      r7
#define subFFTNum       r6
#define N               r6
#define order           r14
#define diff            r9
@ Total num of radix stages to comple the FFT
#define count           r8
#define x0r             r4
#define x0i             r5
#define diffMinusOne    r2
#define round           r3
#define pOut1           r2
#define size            r7
#define step            r8
#define step1           r9
#define twStep          r10
#define pTwiddleTmp     r11
#define argTwiddle1     r12
#define zero            r14

@ Neon registers
#define dX0             D0.S32
#define dShift          D1.S32
#define qShift          Q0.s16
#define dX1             D1.S32
#define dY0             D2.S32
#define dY1             D3.S32
#define dX0r            D0.S32
#define dX0i            D1.S32
#define dX1r            D2.S32
#define dX1i            D3.S32
#define dW0r            D4.S32
#define dW0i            D5.S32
#define dW1r            D6.S32
#define dW1i            D7.S32
#define dT0             D8.S32
#define dT1             D9.S32
#define dT2             D10.S32
#define dT3             D11.S32
#define qT0             Q6.S64
#define qT1             Q7.S64
#define qT0s            Q6.S16
#define qT1s            Q7.S16
#define qT2             Q8.S64
#define qT3             Q9.S64
#define dY0r            D4.S32
#define dY0i            D5.S32
#define dY1r            D6.S32
#define dY1i            D7.S32
#define dzero           D20.S32
#define dY2             D4.S32
#define dY3             D5.S32
#define dW0             D6.S32
#define dW1             D7.S32
#define dW0Tmp          D10.S32
#define dW1Neg          D11.S32



    @ Allocate stack memory required by the function
        M_ALLOC4        diffOnStack, 4

    @ Write function header
        M_START     omxSP_FFTInv_CCSToR_S16_Sfs,r11,d15

@ Structure offsets for the FFTSpec
        .set    ARMsFFTSpec_N, 0
        .set    ARMsFFTSpec_pBitRev, 4
        .set    ARMsFFTSpec_pTwiddle, 8
        .set    ARMsFFTSpec_pBuf, 12

        @ Define stack arguments

        @ Read the size from structure and take log
        LDR     N, [pFFTSpec, #ARMsFFTSpec_N]

        @ Read other structure parameters
        LDR     pTwiddle, [pFFTSpec, #ARMsFFTSpec_pTwiddle]
        LDR     pOut, [pFFTSpec, #ARMsFFTSpec_pBuf]

        @ Call the preTwiddle Radix2 stage before doing the complex IFFT

        @ The following conditional BL combination would work since
        @ evenOddButterflyLoop in the first call would set Z flag to zero

        CMP     scale,#0
        BLEQ    armSP_FFTInv_CCSToR_S16_preTwiddleRadix2_unsafe
        BLGT    armSP_FFTInv_CCSToR_S16_Sfs_preTwiddleRadix2_unsafe

complexIFFT:

        ASR     N,N,#1                              @ N/2 point complex IFFT
        ADD     pSrc,pOut,N,LSL #2                  @ set pSrc as pOut1

        CLZ     order,N                             @ N = 2^order
        RSB     order,order,#31
        MOV     subFFTSize,#1

        ADD     scale,scale,order                   @ FFTInverse has a final scaling factor by N

        CMP     order,#3
        BGT     orderGreaterthan3                   @ order > 3

        CMP     order,#1
        BGE     orderGreaterthan0                   @ order > 0
        M_STR   scale, diffOnStack,LT               @ order = 0
        LDRLT   x0r,[pSrc]
        STRLT   x0r,[pDst]
        MOVLT   pSrc,pDst
        BLT     FFTEnd

orderGreaterthan0:
        @ set the buffers appropriately for various orders
        CMP     order,#2
        MOVNE   argDst,pDst
        MOVEQ   argDst,pOut
        MOVEQ   pOut,pDst                           @ Pass the first stage destination in RN5
        MOV     argTwiddle,pTwiddle
        @ Store the scale factor and scale at the end
        SUB     diff,scale,order
        M_STR   diff, diffOnStack
        BGE     orderGreaterthan1
        BLLT    armSP_FFTInv_CToC_SC16_Sfs_Radix2_fs_OutOfPlace_unsafe  @ order = 1
        B       FFTEnd


orderGreaterthan1:
        MOV     tmpOrder,order                      @ tmpOrder = RN 4
        BL      armSP_FFTInv_CToC_SC16_Sfs_Radix2_fs_OutOfPlace_unsafe
        CMP     tmpOrder,#2
        BLGT    armSP_FFTInv_CToC_SC16_Sfs_Radix2_ps_OutOfPlace_unsafe
        BL      armSP_FFTInv_CToC_SC16_Sfs_Radix2_ls_OutOfPlace_unsafe
        B       FFTEnd




orderGreaterthan3:
        @ check scale = 0 or scale = order
        SUB     diff, scale, order                  @ scale > order

        TST     order, #2                           @ Set input args to fft stages
        MOVNE   argDst,pDst
        MOVEQ   argDst,pOut
        MOVEQ   pOut,pDst                           @ Pass the first stage destination in RN5
        MOV     argTwiddle,pTwiddle

        CMP     diff,#0
        M_STR   diff, diffOnStack
        BGE     scaleEqualsOrder

        @check for even or odd order
        @ NOTE: The following combination of BL's would work fine eventhough the first
        @ BL would corrupt the flags. This is because the end of the "grpZeroSetLoop" loop inside
        @ armSP_FFTInv_CToC_SC16_Radix4_fs_OutOfPlace_unsafe sets the Z flag to EQ

        TST     order,#0x00000001
        BLEQ    armSP_FFTInv_CToC_SC16_Radix4_fs_OutOfPlace_unsafe
        BLNE    armSP_FFTInv_CToC_SC16_Radix8_fs_OutOfPlace_unsafe

        CMP     subFFTNum,#4
        BLT     FFTEnd

unscaledRadix4Loop:
        BEQ     lastStageUnscaledRadix4
        BL      armSP_FFTInv_CToC_SC16_Radix4_OutOfPlace_unsafe
        CMP     subFFTNum,#4
        B       unscaledRadix4Loop

lastStageUnscaledRadix4:
        BL      armSP_FFTInv_CToC_SC16_Radix4_ls_OutOfPlace_unsafe
        B       FFTEnd

scaleEqualsOrder:
        @check for even or odd order
        @ NOTE: The following combination of BL's would work fine eventhough the first
        @ BL would corrupt the flags. This is because the end of the "grpZeroSetLoop" loop inside
        @ armSP_FFTInv_CToC_SC32_Radix4_fs_OutOfPlace_unsafe sets the Z flag to EQ

        TST     order,#0x00000001
        BLEQ    armSP_FFTInv_CToC_SC16_Sfs_Radix4_fs_OutOfPlace_unsafe
        BLNE    armSP_FFTInv_CToC_SC16_Sfs_Radix8_fs_OutOfPlace_unsafe

        CMP     subFFTNum,#4
        BLT     FFTEnd

scaledRadix4Loop:
        BEQ     lastStageScaledRadix4
        BL      armSP_FFTInv_CToC_SC16_Sfs_Radix4_OutOfPlace_unsafe
        CMP     subFFTNum,#4
        B       scaledRadix4Loop

lastStageScaledRadix4:
        BL      armSP_FFTInv_CToC_SC16_Sfs_Radix4_ls_OutOfPlace_unsafe

FFTEnd:                                         @ Does only the scaling

        M_LDR   diff, diffOnStack
        CMP     diff,#0
        BLE     End

        RSB     diff,diff,#0                    @ to use VRSHL for right shift by a variable
        VDUP    qShift,diff

        @ Use parallel loads for bigger FFT size.
        CMP     subFFTSize, #8
        BLT     scaleLessFFTData

scaleFFTData:
        VLD1    {qT0s, qT1s},[pSrc:256]         @ pSrc contains pDst pointer
        SUBS    subFFTSize,subFFTSize,#8
        VSHL    qT0s,qShift
        VSHL    qT1s,qShift
        VST1    {qT0s, qT1s},[pSrc:256]!
        BGT     scaleFFTData
        B       End

scaleLessFFTData:                               @ N = subFFTSize  ; dataptr = pDst  ; scale = diff
        VLD1    {dX0[0]},[pSrc]                 @ pSrc contains pDst pointer
        SUBS    subFFTSize,subFFTSize,#1
        VRSHL   dX0,dShift
        VST1    {dX0[0]},[pSrc]!
        BGT     scaleLessFFTData

End:
        @ Set return value
        MOV     result, #OMX_Sts_NoErr

        @ Write function tail
        M_END






    .END
