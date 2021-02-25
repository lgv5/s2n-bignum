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
; Extended Montgomery reduce, returning results in input-output buffer
; Inputs z[2*k], m[k], w; outputs function return (extra result bit) and z[2*k]
;
;    extern uint64_t bignum_emontredc
;     (uint64_t k, uint64_t *z, uint64_t *m, uint64_t w);
;
; Assumes that z initially holds a 2k-digit bignum z_0, m is a k-digit odd
; bignum and m * w == -1 (mod 2^64). This function also uses z for the output
; as well as returning a carry c of 0 or 1. This encodes two numbers: in the
; lower half of the z buffer we have q = z[0..k-1], while the upper half
; together with the carry gives r = 2^{64k}*c + z[k..2k-1]. These values
; satisfy z_0 + q * m = 2^{64k} * r, i.e. r gives a raw (unreduced) Montgomery
; reduction while q gives the multiplier that was used. Another way of
; thinking of it is that if z' is the output z with the lower half replaced
; with zeros, then z_0 + q * m = 2^{128k} * c + z'.
;
; Standard x86-64 ABI: RDI = k, RSI = z, RDX = m, RCX = w, returns RAX
; ----------------------------------------------------------------------------

%define k rdi
%define z rsi
%define m r8            ; Comes in in rdx but we copy it here
%define w rcx

%define a rax           ; General temp, low part of product and mul input
%define b rdx           ; General temp, High part of product
%define d rbx           ; Home for i'th digit or Montgomery multiplier

%define i r9            ; Outer loop counter
%define j r10           ; Inner loop counter

%define h r11
%define e r12
%define t r13
%define c r14

                global  bignum_emontredc
                section .text

bignum_emontredc:

; Save registers

                push    rbx
                push    r12
                push    r13
                push    r14

; Initialize top carry to zero immediately to catch the k = 0 case

                xor     c, c

; If k = 0 the whole operation is trivial

                test    k, k
                jz      end

; Move m into its permanent home since we need RDX for muls

                mov     m, rdx

; Launch into the outer loop

                xor     i, i
outerloop:
                mov     e, [z]
                mov     d, w
                imul    d, e
                mov     a, [m]
                mul     d
                mov     [z], d
                add     a, e            ; Will be zero but want the carry
                mov     h, rdx
                mov     j, 1
                mov     t, k
                dec     t
                jz      montend

montloop:
                adc     h, [z+8*j]
                sbb     e, e
                mov     a, [m+8*j]
                mul     d
                sub     rdx, e
                add     a, h
                mov     [z+8*j], a
                mov     h, rdx
                inc     j
                dec     t
                jnz     montloop

montend:
                adc     h, c
                mov     c, 0
                adc     c, 0
                mov     a, [z+8*k]
                add     a, h
                mov     [z+8*k], a
                adc     c, 0

; End of outer loop.

                add     z, 8    ; For simple indexing, z pointer moves
                inc     i
                cmp     i, k
                jc      outerloop

end:

; Put the top carry in the expected place, restore registers and return

                mov     rax, c
                pop     r14
                pop     r13
                pop     r12
                pop     rbx
                ret
