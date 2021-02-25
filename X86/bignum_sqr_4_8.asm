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
; Square, z := x^2
; Input x[4]; output z[8]
;
;    extern void bignum_sqr_4_8 (uint64_t z[static 8], uint64_t x[static 4]);
;
; Standard x86-64 ABI: RDI = z, RSI = x
; ----------------------------------------------------------------------------

; These are actually right

%define z rdi
%define x rsi

; A zero register

%define zero rbp

; Other registers

%define d1 r8
%define d2 r9
%define d3 r10
%define d4 r11
%define d5 r12
%define d6 r13

                global  bignum_sqr_4_8
                section .text

bignum_sqr_4_8:

; Save more registers to play with

        push    rbp
        push    r12
        push    r13

; Set up an initial window [d6;...d1] = [23;03;01]

        mov     rdx, [x]
        mulx    d2, d1, [x+8*1]
        mulx    d4, d3, [x+8*3]
        mov     rdx, [x+8*2]
        mulx    d6, d5, [x+8*3]

; Clear our zero register, and also initialize the flags for the carry chain

        xor     zero, zero

; Chain in the addition of 02 + 12 + 13 to that window (no carry-out possible)
; This gives all the "heterogeneous" terms of the squaring ready to double

        mulx    rcx, rax, [x]
        adcx    d2, rax
        adox    d3, rcx
        mulx    rcx, rax, [x+8*1]
        adcx    d3, rax
        adox    d4, rcx
        mov     rdx, [x+8*3]
        mulx    rcx, rax, [x+8*1]
        adcx    d4, rax
        adox    d5, rcx
        adcx    d5, zero
        adox    d6, zero
        adcx    d6, zero

; In principle this is otiose as CF and OF carries are absorbed at this point
; However it seems helpful for the OOO engine to be told it's a fresh start

        xor     zero, zero

; Double and add to the 00 + 11 + 22 + 33 terms
;
; We could use shift-double but this seems tidier and in larger squarings
; it was actually more efficient. I haven't experimented with this small
; case to see how much that matters. Note: the writeback here is sprinkled
; into the sequence in such a way that things still work if z = x, i.e. if
; the output overwrites the input buffer and beyond.

        mov     rdx, [x]
        mulx    rdx, rax, rdx
        mov     [z], rax
        adcx    d1, d1
        adox    d1, rdx
        mov     rdx, [x+8*1]
        mov     [z+8*1], d1
        mulx    rdx, rax, rdx
        adcx    d2, d2
        adox    d2, rax
        adcx    d3, d3
        adox    d3, rdx
        mov     rdx, [x+8*2]
        mov     [z+8*2], d2
        mulx    rdx, rax, rdx
        adcx    d4, d4
        adox    d4, rax
        adcx    d5, d5
        adox    d5, rdx
        mov     rdx, [x+8*3]
        mov     [z+8*3], d3
        mulx    rdx, rax, rdx
        mov     [z+8*4], d4
        adcx    d6, d6
        mov     [z+8*5], d5
        adox    d6, rax
        mov     [z+8*6], d6
        adcx    rdx, zero
        adox    rdx, zero
        mov     [z+8*7], rdx

; Restore saved registers and return

        pop     r13
        pop     r12
        pop     rbp

        ret
