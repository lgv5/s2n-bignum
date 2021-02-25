 ; * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 ; *
 ; * Licensed under the Apache License, Version 2.0 (the "License").
 ; * You may not use this file except in compliance with the License.
 ; * A copy of the License is located at
 ; *
 ; *  http://aws.amazon.com/apache2.0
 ; *
 ; * or in the "LICENSE" file accompanying this file. This file is distributed
 ; * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 ; * express or implied. See the License for the specific language governing
 ; * permissions and limitations under the License.

; ----------------------------------------------------------------------------
; Double modulo p_256, z := (2 * x) mod p_256, assuming x reduced
; Input x[4]; output z[4]
;
;    extern void bignum_double_p256
;     (uint64_t z[static 4], uint64_t x[static 4]);
;
; Standard x86-64 ABI: RDI = z, RSI = x
; ----------------------------------------------------------------------------

%define z rdi
%define x rsi

%define d0 rdx
%define d1 rcx
%define d2 r8
%define d3 r9

%define n1 r10
%define n3 r11
%define c rax

        global  bignum_double_p256

bignum_double_p256:

; Load the input and double it so that 2^256 * c + [d3;d2;d1;d0] = 2 * x
; Could also consider using shld to decouple carries

        xor     c, c
        mov     d0, [x]
        add     d0, d0
        mov     d1, [x+8]
        adc     d1, d1
        mov     d2, [x+16]
        adc     d2, d2
        mov     d3, [x+24]
        adc     d3, d3
        adc     c, c

; Now subtract 2^256 * c + [d3;d3;d1;d1] = 2 * x - p_256
; The constants n1 and n3 in [n3; 0; n1; -1] = p_256 are saved for later

        sub     d0, -1
        mov     n1, 0x00000000ffffffff
        sbb     d1, n1
        sbb     d2, 0
        mov     n3, 0xffffffff00000001
        sbb     d3, n3

; Since by hypothesis x < p_256 we know 2 * x - p_256 < 2^256, so the top
; carry c actually gives us a bitmask for 2 * x - p_256 < 0, which we
; now use to make a masked p_256' = [n3; 0; n1; c]

        sbb     c, 0
        and     n1, c
        and     n3, c

; Do the corrective addition and copy to output

        add     d0, c
        mov     [z], d0
        adc     d1, n1
        mov     [z+8], d1
        adc     d2, 0
        mov     [z+16], d2
        adc     d3, n3
        mov     [z+24], d3

        ret
