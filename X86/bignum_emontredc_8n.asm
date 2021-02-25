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
; Extended Montgomery reduce in 8-digit blocks, results in input-output buffer
; Inputs z[2*k], m[k], w; outputs function return (extra result bit) and z[2*k]
;
;    extern uint64_t bignum_emontredc_8n
;     (uint64_t k, uint64_t *z, uint64_t *m, uint64_t w);
;
; Functionally equivalent to bignum_emontredc (see that file for more detail).
; But in general assumes that the input k is a multiple of 8.
;
; Standard x86-64 ABI: RDI = k, RSI = z, RDX = m, RCX = w, returns RAX
; ----------------------------------------------------------------------------

                global bignum_emontredc_8n

; Original input parameters are here

%define z rsi
%define w rcx

; This is copied in early once we stash away k

%define m rdi

; A variable z pointer

%define zz rbp

; Stack-based variables

%define carry QWORD[rsp]
%define innercount QWORD[rsp+8]
%define outercount QWORD[rsp+16]
%define k8m1 QWORD[rsp+24]

; -----------------------------------------------------------------------------
; Standard macros as used in pure multiplier arrays
; -----------------------------------------------------------------------------

; mulpadd i, j adds z[i] * rdx (now assumed = m[j]) into the window at i+j

%macro mulpadd 2
        mulx    rbx, rax, [z+8*%1]
%if ((%1 + %2) % 8 == 0)
        adcx    r8, rax
        adox    r9, rbx
%elif ((%1 + %2) % 8 == 1)
        adcx    r9, rax
        adox    r10, rbx
%elif ((%1 + %2) % 8 == 2)
        adcx    r10, rax
        adox    r11, rbx
%elif ((%1 + %2) % 8 == 3)
        adcx    r11, rax
        adox    r12, rbx
%elif ((%1 + %2) % 8 == 4)
        adcx    r12, rax
        adox    r13, rbx
%elif ((%1 + %2) % 8 == 5)
        adcx    r13, rax
        adox    r14, rbx
%elif ((%1 + %2) % 8 == 6)
        adcx    r14, rax
        adox    r15, rbx
%elif ((%1 + %2) % 8 == 7)
        adcx    r15, rax
        adox    r8, rbx
%endif

%endm

; addrow i adds z[i] + zz[0..7] * m[j] into the window

%macro addrow 1
        mov     rdx, [m+8*%1]
        xor     rax, rax         ; Get a known flag state

%if (%1 % 8 == 0)
        adox    r8, [zz+8*%1]
%elif (%1 % 8 == 1)
        adox    r9, [zz+8*%1]
%elif (%1 % 8 == 2)
        adox    r10, [zz+8*%1]
%elif (%1 % 8 == 3)
        adox    r11, [zz+8*%1]
%elif (%1 % 8 == 4)
        adox    r12, [zz+8*%1]
%elif (%1 % 8 == 5)
        adox    r13, [zz+8*%1]
%elif (%1 % 8 == 6)
        adox    r14, [zz+8*%1]
%elif (%1 % 8 == 7)
        adox    r15, [zz+8*%1]
%endif

        mulpadd 0, %1

%if (%1 % 8 == 0)
        mov     [zz+8*%1], r8
        mov     r8, 0
%elif (%1 % 8 == 1)
        mov     [zz+8*%1], r9
        mov     r9, 0
%elif (%1 % 8 == 2)
        mov     [zz+8*%1], r10
        mov     r10, 0
%elif (%1 % 8 == 3)
        mov     [zz+8*%1], r11
        mov     r11, 0
%elif (%1 % 8 == 4)
        mov     [zz+8*%1], r12
        mov     r12, 0
%elif (%1 % 8 == 5)
        mov     [zz+8*%1], r13
        mov     r13, 0
%elif (%1 % 8 == 6)
        mov     [zz+8*%1], r14
        mov     r14, 0
%elif (%1 % 8 == 7)
        mov     [zz+8*%1], r15
        mov     r15, 0
%endif

        mulpadd 1, %1
        mulpadd 2, %1
        mulpadd 3, %1
        mulpadd 4, %1
        mulpadd 5, %1
        mulpadd 6, %1
        mulpadd 7, %1

%if (%1 % 8 == 0)
        adc     r8, 0
%elif (%1 % 8 == 1)
        adc     r9, 0
%elif (%1 % 8 == 2)
        adc     r10, 0
%elif (%1 % 8 == 3)
        adc     r11, 0
%elif (%1 % 8 == 4)
        adc     r12, 0
%elif (%1 % 8 == 5)
        adc     r13, 0
%elif (%1 % 8 == 6)
        adc     r14, 0
%elif (%1 % 8 == 7)
        adc     r15, 0
%endif


%endm

; -----------------------------------------------------------------------------
; Anti-matter versions with z and m switched, and also not writing back the z
; words, but the inverses instead, *and* also adding in the z[0..7] at the
; beginning. The aim is to use this in Montgomery where we discover z[j]
; entries as we go along.
; -----------------------------------------------------------------------------

%macro mulpadda 2
        mulx    rbx, rax, [m+8*%1]
%if ((%1 + %2) % 8 == 0)
        adcx    r8, rax
        adox    r9, rbx
%elif ((%1 + %2) % 8 == 1)
        adcx    r9, rax
        adox    r10, rbx
%elif ((%1 + %2) % 8 == 2)
        adcx    r10, rax
        adox    r11, rbx
%elif ((%1 + %2) % 8 == 3)
        adcx    r11, rax
        adox    r12, rbx
%elif ((%1 + %2) % 8 == 4)
        adcx    r12, rax
        adox    r13, rbx
%elif ((%1 + %2) % 8 == 5)
        adcx    r13, rax
        adox    r14, rbx
%elif ((%1 + %2) % 8 == 6)
        adcx    r14, rax
        adox    r15, rbx
%elif ((%1 + %2) % 8 == 7)
        adcx    r15, rax
        adox    r8, rbx
%endif

%endm

%macro adurowa 1
        mov     rdx, w          ; Get the word-level modular inverse
        xor     rax, rax        ; Get a known flag state
%if (%1 % 8 == 0)
        mulx    rax, rdx, r8
%elif (%1 % 8 == 1)
        mulx    rax, rdx, r9
%elif (%1 % 8 == 2)
        mulx    rax, rdx, r10
%elif (%1 % 8 == 3)
        mulx    rax, rdx, r11
%elif (%1 % 8 == 4)
        mulx    rax, rdx, r12
%elif (%1 % 8 == 5)
        mulx    rax, rdx, r13
%elif (%1 % 8 == 6)
        mulx    rax, rdx, r14
%elif (%1 % 8 == 7)
        mulx    rax, rdx, r15
%endif

        mov     [z+8*%1], rdx   ; Store multiplier word

        mulpadda 0, %1

        ; Note that the bottom reg of the window is zero by construction
        ; So it's safe just to use "mulpadda 7" here

        mulpadda 1, %1
        mulpadda 2, %1
        mulpadda 3, %1
        mulpadda 4, %1
        mulpadda 5, %1
        mulpadda 6, %1
        mulpadda 7, %1          ; window lowest = 0 beforehand by construction

%if (%1 % 8 == 0)
        adc     r8, 0
%elif (%1 % 8 == 1)
        adc     r9, 0
%elif (%1 % 8 == 2)
        adc     r10, 0
%elif (%1 % 8 == 3)
        adc     r11, 0
%elif (%1 % 8 == 4)
        adc     r12, 0
%elif (%1 % 8 == 5)
        adc     r13, 0
%elif (%1 % 8 == 6)
        adc     r14, 0
%elif (%1 % 8 == 7)
        adc     r15, 0
%endif

%endm

%macro adurowza 0
        mov     rdx, w          ; Get the word-level modular inverse
        xor     rax, rax        ; Get a known flag state

        mov     r8, [z]         ; r8 = zeroth word
        mulx    rax, rdx, r8    ; Compute multiplier word
        mov     [z], rdx        ; Store multiplier word
        mov     r9, [z+8*1]

        mulpadda 0, 0
        mov     r10, [z+8*2]
        mulpadda 1, 0
        mov     r11, [z+8*3]
        mulpadda 2, 0
        mov     r12, [z+8*4]
        mulpadda 3, 0
        mov     r13, [z+8*5]
        mulpadda 4, 0
        mov     r14, [z+8*6]
        mulpadda 5, 0
        mov     r15, [z+8*7]
        mulpadda 6, 0
        mulpadda 7, 0           ; r8 = 0 beforehand by construction
        adc     r8, 0
%endm

; -----------------------------------------------------------------------------
; Hybrid top, doing an 8 block specially then multiple additional 8 blocks
; -----------------------------------------------------------------------------

; Multiply-add: z := z + x[i...i+7] * m

%macro addrows 0

        adurowza
        adurowa 1
        adurowa 2
        adurowa 3
        adurowa 4
        adurowa 5
        adurowa 6
        adurowa 7

        mov     zz, z

        mov     rax, k8m1
        test    rax, rax
        jz      innerend
        mov     innercount, rax
innerloop:
        add     zz, 64
        add     m, 64
        addrow 0
        addrow 1
        addrow 2
        addrow 3
        addrow 4
        addrow 5
        addrow 6
        addrow 7
        sub     innercount, 64
        jnz     innerloop

        mov     rax, k8m1
innerend:
        sub     m, rax

        mov     rbx, carry
        neg     rbx
        adc     [z+rax+64], r8
        adc     [z+rax+72], r9
        adc     [z+rax+80], r10
        adc     [z+rax+88], r11
        adc     [z+rax+96], r12
        adc     [z+rax+104], r13
        adc     [z+rax+112], r14
        adc     [z+rax+120], r15
        mov     rax, 0
        adc     rax, 0
        mov     carry, rax
%endm

; -----------------------------------------------------------------------------
; Main code.
; -----------------------------------------------------------------------------

bignum_emontredc_8n:

; Save more registers to play with

        push    rbp
        push    rbx
        push    r12
        push    r13
        push    r14
        push    r15

; Pre-initialize the return value to 0 just in case of early exit below

        xor     rax, rax

; Divide the input k by 8, and push k8m1 = (k/8 - 1)<<6 which is used as
; the scaled inner loop counter / pointer adjustment repeatedly. Also push
; k/8 itself which is here initializing the outer loop count.

        shr     rdi, 3
        jz      end

        lea     rbx, [rdi-1]
        shl     rbx, 6
        push    rbx
        push    rdi

; Make space for two more variables, and set between-stages carry to 0

        sub     rsp, 16
        mov     carry, 0

; Copy m into its main home

        mov     m, rdx

; Now just systematically add in the rows

outerloop:
        addrows
        add     z, 64
        sub     outercount, 1
        jnz     outerloop

; Pop the carry-out "p", which was stored at [rsp], put in rax for return

        pop     rax

; Adjust the stack

        add     rsp, 24

; Reset of epilog

end:

        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        pop     rbp

        ret
