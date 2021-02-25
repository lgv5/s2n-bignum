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
; Triple modulo p_384, z := (3 * x) mod p_384
; Input x[6]; output z[6]
;
;    extern void bignum_triple_p384
;     (uint64_t z[static 6], uint64_t x[static 6]);
;
; The input x can be any 6-digit bignum, not necessarily reduced modulo p_384,
; and the result is always fully reduced, i.e. z = (3 * x) mod p_384.
;
; Standard x86-64 ABI: RDI = z, RSI = x
; ----------------------------------------------------------------------------

%define z rdi
%define x rsi

%define d0 r8
%define d1 r9
%define d2 r10
%define d3 r11
%define d4 rbx
%define d5 rsi

%define a rax
%define c rcx
%define q rdx

        section .text
        global  bignum_triple_p384

bignum_triple_p384:

; We seem to need (just!) one extra register, which we need to save and restore

                push    rbx

; Multiply, accumulating the result as 2^384 * h + [d5;d4;d3;d2;d1;d0]
; but actually immediately producing q = h + 1, our quotient approximation,
; by adding 1 to it. Note that by hypothesis x is reduced mod p_384, so our
; product is <= (2^64 - 1) * (p_384 - 1) and hence  h <= 2^64 - 2, meaning
; there is no danger this addition of 1 could wrap.

                mov     q, 3
                mulx    d1, d0, [x]
                mulx    d2, a, [x+8]
                add     d1, a
                mulx    d3,a, [x+16]
                adc     d2, a
                mulx    d4,a, [x+24]
                adc     d3, a
                mulx    c, a, [x+32]
                adc     d4, a
                mulx    q, d5, [x+40]
                adc     d5, c
                adc     q, 1

; Initial subtraction of z - q * p_384, with bitmask c for the carry
; Actually done as an addition of (z - 2^384 * h) + q * (2^384 - p_384)
; which, because q = h + 1, is exactly 2^384 + (z - q * p_384), and
; therefore CF <=> 2^384 + (z - q * p_384) >= 2^384 <=> z >= q * p_384.

                mov     c, q
                shl     c, 32
                mov     a, q
                sub     a, c
                sbb     c, 0

                add     d0, a
                adc     d1, c
                adc     d2, q
                adc     d3, 0
                adc     d4, 0
                adc     d5, 0
                sbb     c, c
                not     c

; Now use that mask for a masked addition of p_384, which again is in
; fact done by a masked subtraction of 2^384 - p_384, so that we only
; have three nonzero digits and so can avoid using another register.

                mov     q, 0x00000000ffffffff
                xor     a, a
                and     q, c
                sub     a, q
                and     c, 1

                sub     d0, a
                mov     [z], d0
                sbb     d1, q
                mov     [z+8], d1
                sbb     d2, c
                mov     [z+16], d2
                sbb     d3, 0
                mov     [z+24], d3
                sbb     d4, 0
                mov     [z+32], d4
                sbb     d5, 0
                mov     [z+40], d5

; Return

                pop     rbx
                ret
