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
; Reduce modulo field characteristic, z := x mod p_384
; Input x[k]; output z[6]
;
;    extern void bignum_mod_p384
;     (uint64_t z[static 6], uint64_t k, uint64_t *x);
;
; Standard x86-64 ABI: RDI = z, RSI = k, RDX = x
; ----------------------------------------------------------------------------

%define z rdi
%define k rsi
%define x rcx

%define m0 r8
%define m1 r9
%define m2 r10
%define m3 r11
%define m4 r12
%define m5 r13
%define d r14

%define n0 rax
%define n1 rbx
%define n2 rdx
%define q rdx

        section .text
        global  bignum_mod_p384

bignum_mod_p384:

; Save extra registers

                push    rbx
                push    r12
                push    r13
                push    r14

; If the input is already <= 5 words long, go to a trivial "copy" path

                cmp     k, 6
                jc      shortinput

; Otherwise load the top 6 digits (top-down) and reduce k by 6

                sub     k, 6
                mov     m5, [rdx+8*k+40]
                mov     m4, [rdx+8*k+32]
                mov     m3, [rdx+8*k+24]
                mov     m2, [rdx+8*k+16]
                mov     m1, [rdx+8*k+8]
                mov     m0, [rdx+8*k]

; Move x into another register to leave rdx free for multiplies and use of n2

                mov     x, rdx

; Reduce the top 6 digits mod p_384 (a conditional subtraction of p_384)

                mov     n0, 0x00000000ffffffff
                mov     n1, 0xffffffff00000000
                mov     n2, 0xfffffffffffffffe

                sub     m0, n0
                sbb     m1, n1
                sbb     m2, n2
                sbb     m3, -1
                sbb     m4, -1
                sbb     m5, -1

                sbb     d, d
                and     n0, d
                and     n1, d
                and     n2, d
                add     m0, n0
                adc     m1, n1
                adc     m2, n2
                adc     m3, d
                adc     m4, d
                adc     m5, d

; Now do (k-6) iterations of 7->6 word modular reduction

                test    k, k
                jz      writeback

loop:

; Compute q = min (m5 + 1) (2^64 - 1)

                mov     q, 1
                add     q, m5
                sbb     d, d
                or      q, d

; Load the next digit so current m to reduce = [m5;m4;m3;m2;m1;m0;d]

                mov     d, [x+8*k-8]

; Now form [m5;m4;m3;m2;m1;m0;d] = m - q * p_384. To use an addition for
; the main calculation we do (m - 2^384 * q) + q * (2^384 - p_384)
; where 2^384 - p_384 = [0;0;0;1;0x00000000ffffffff;0xffffffff00000001].
; The extra subtraction of 2^384 * q is the first instruction.

                sub     m5, q
                xor     n0, n0
                mov     n0, 0xffffffff00000001
                mulx    n1, n0, n0
                adcx    d, n0
                adox    m0, n1
                mov     n0, 0x00000000ffffffff
                mulx    n1, n0, n0
                adcx    m0, n0
                adox    m1, n1
                adcx    m1, q
                mov     n0, 0
                adox    n0, n0
                adcx    m2, n0
                adc     m3, 0
                adc     m4, 0
                adc     m5, 0

; Now our top word m5 is either zero or all 1s. Use it for a masked
; addition of p_384, which we can do by a *subtraction* of
; 2^384 - p_384 from our portion

                mov     n0, 0xffffffff00000001
                and     n0, m5
                mov     n1, 0x00000000ffffffff
                and     n1, m5
                and     m5, 1

                sub     d, n0
                sbb     m0, n1
                sbb     m1, m5
                sbb     m2, 0
                sbb     m3, 0
                sbb     m4, 0

; Now shuffle registers up and loop

                mov     m5, m4
                mov     m4, m3
                mov     m3, m2
                mov     m2, m1
                mov     m1, m0
                mov     m0, d

                dec     k
                jnz     loop

; Write back

writeback:

                mov     [z], m0
                mov     [z+8], m1
                mov     [z+16], m2
                mov     [z+24], m3
                mov     [z+32], m4
                mov     [z+40], m5

; Restore registers and return

                pop     r14
                pop     r13
                pop     r12
                pop     rbx
                ret

shortinput:

                xor     m0, m0
                xor     m1, m1
                xor     m2, m2
                xor     m3, m3
                xor     m4, m4
                xor     m5, m5

                test    k, k
                jz      writeback
                mov     m0, [rdx]
                dec     k
                jz      writeback
                mov     m1, [rdx + 8]
                dec     k
                jz      writeback
                mov     m2, [rdx + 16]
                dec     k
                jz      writeback
                mov     m3, [rdx + 24]
                dec     k
                jz      writeback
                mov     m4, [rdx + 32]
                jmp     writeback
