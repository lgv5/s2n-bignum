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
; Normalize bignum in-place by shifting left till top bit is 1
; Input z[k]; outputs function return (bits shifted left) and z[k]
;
;    extern uint64_t bignum_normalize (uint64_t k, uint64_t *z);
;
; Given a k-digit bignum z, this function shifts it left by its number of
; leading zero bits, to give result with top bit 1, unless the input number
; was 0. The return is the same as the output of bignum_clz, i.e. the number
; of bits shifted (nominally 64 * k in the case of zero input).
;
; Standard x86-64 ABI: RDI = k, RSI = z, returns RAX
; ----------------------------------------------------------------------------

%define k rdi
%define z rsi

; Return value, which we put in rax to save a move or two

%define r rax

; Other variables

%define b r9
%define c rcx   ; Matters that this is RCX as CL=lo(c) is assumed in shifts
%define d rdx
%define i r8
%define j r10


                global  bignum_normalize
                section .text

bignum_normalize:

; Initialize shift count r = 0 and i = k - 1 but return immediately if k = 0.
; Otherwise load top digit c, but then if k = 1 skip the digitwise part

                xor     r, r
                mov     i, k
                sub     i, 1
                jc      end
                mov     c, [z+8*i]
                jz      bitpart

; Do d rather stupid but constant-time digit normalization, conditionally
; shifting left (k-1) times based on whether the top word is zero.
; With careful binary striding this could be O(k*log(k)) instead of O(k^2)
; while still retaining the constant-time style.

normloop:
                xor     j, j
                mov     b, k
                mov     d, r
                inc     r
                neg     c
                cmovne  r, d
                mov     d, 0
shufloop:
                mov     c, d
                mov     d, [z+8*j]
                cmovc   c, d
                mov     [z+8*j], c
                inc     j
                dec     b
                jnz     shufloop
                dec     i
                jnz     normloop

; We now have the top digit nonzero, assuming the input was nonzero,
; and as per the invariant of the loop above, c holds that digit. So
; now just count c's leading zeros and shift z bitwise that many bits.
; We need to patch the bsr result for the undefined case of zero input

bitpart:
                mov     d, 127
                bsr     c, c
                cmovz   c, d
                xor     c, 63

                shl     r, 6
                add     r, c

                xor     b, b
                xor     i, i
bitloop:
                mov     d, [z+8*i]
                mov     j, d
                shld    d, b, cl
                mov     [z+8*i],d
                mov     b, j
                inc     i
                cmp     i, k
                jc      bitloop

 end:
                ret
