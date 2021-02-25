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
; Multiply by a single word, z := c * y
; Inputs c, y[n]; outputs function return (carry-out) and z[k]
;
;    extern uint64_t bignum_cmul
;     (uint64_t k, uint64_t *z, uint64_t c, uint64_t n, uint64_t *y);
;
; Does the "z := c * y" operation where y is n digits, result z is p.
; Truncates the result in general unless p >= n + 1.
;
; The return value is a high/carry word that is meaningful when p >= n as
; giving the high part of the result. Since this is always zero if p > n,
; it is mainly of interest in the special case p = n, i.e. where the source
; and destination have the same nominal size, when it gives the extra word
; of the full result.
;
; Standard x86-64 ABI: RDI = k, RSI = z, RDX = c, RCX = n, R8 = y, returns RAX
; ----------------------------------------------------------------------------

%define p rdi
%define z rsi
%define c r9
%define n rcx
%define x r8

%define i r10
%define h r11

                global  bignum_cmul
                section .text

bignum_cmul:

; First clamp the input size n := min(p,n) since we can never need to read
; past the p'th term of the input to generate p-digit output. Now we can
; assume that n <= p

                cmp     p, n
                cmovc   n, p

; Initialize current input/output pointer offset i and high part h.
; But then if n = 0 skip the multiplication and go to the tail part

                xor     h, h
                xor     i, i
                test    n, n
                jz      tail

; Move c into a safer register as multiplies overwrite rdx

                mov     c, rdx

; Initialization of the loop: [h,l] = c * x_0

                mov     rax, [x]
                mul     c
                mov     [z], rax
                mov     h, rdx
                inc     i
                cmp     i, n
                jz      tail

; Main loop doing the multiplications

loop:
                mov     rax, [x+8*i]
                mul     c
                add     rax, h
                adc     rdx, 0
                mov     [z+8*i], rax
                mov     h, rdx
                inc     i
                cmp     i, n
                jc      loop

; Add a tail when the destination is longer

tail:
                cmp     i, p
                jnc     end
                mov     [z+8*i], h
                xor     h, h
                inc     i
                cmp     i, p
                jnc     end

tloop:
                mov     [z+8*i], h
                inc     i
                cmp     i, p
                jc      tloop

; Return the high/carry word

end:
                mov     rax, h

                ret
