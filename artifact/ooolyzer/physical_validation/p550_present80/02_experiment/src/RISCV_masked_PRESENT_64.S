//////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// RISC-V masked PRESENT /////////////////////////////
//////////////////////////////////      RV64I Port      //////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////


.text

.macro rorA reg,dist
    srliw s8, \reg, \dist
    slliw \reg, \reg, 32-\dist
    xor   \reg, \reg, s8
    addw s8, zero, zero # CLEAR
.endm

.macro rolA reg,dist
    slliw s8, \reg, \dist
    srliw \reg, \reg, 32-\dist
    xor   \reg, \reg, s8
    addw s8, zero, zero # CLEAR
.endm


.macro ror8_1 reg
    andi  s11, \reg, 0x01
    slliw s11, s11, 7
    andi  \reg, \reg, 0xfe
    srliw \reg, \reg, 1
    xor   \reg, \reg, s11
    andi  \reg, \reg, 0xff
    addw s11, zero, zero # CLEAR
    addw s10, zero, zero # CLEAR
.endm

.macro ror8_2 reg
    andi  s11, \reg, 0x03
    slliw s11, s11, 6
    andi  \reg, \reg, 0xfc
    srliw \reg, \reg, 2
    xor   \reg, \reg, s11
    andi  \reg, \reg, 0xff
    addw s11, zero, zero # CLEAR
    addw s10, zero, zero # CLEAR
.endm

.macro rol8_1 reg
    andi  s11, \reg, 0x80
    srliw s11, s11, 7
    andi  \reg, \reg, 0x7f
    slliw \reg, \reg, 1
    xor   \reg, \reg, s11
    andi  \reg, \reg, 0xff
    addw s11, zero, zero # CLEAR
    addw s10, zero, zero # CLEAR
.endm

.macro rol8_2 reg
    andi  s11, \reg, 0xC0
    srliw s11, s11, 6
    andi  \reg, \reg, 0x3f
    slliw \reg, \reg, 2
    xor   \reg, \reg, s11
    andi  \reg, \reg, 0xff
    addw s11, zero, zero # CLEAR
    addw s10, zero, zero # CLEAR
.endm


.macro big_ror_1 reg
    # p1
    andi s8, \reg, 0xFF
    # p2
    srliw s9, \reg, 8
    ror8_1 s8
    ror8_1 s9
    slliw s9, s9, 8
    xor \reg, s8, s9
    addw s8, zero, zero # CLEAR
    addw s9, zero, zero # CLEAR
.endm


.macro big_ror_2 reg
    # p1
    andi s8, \reg, 0xFF
    # p2
    srliw s9, \reg, 8
    ror8_2 s8
    ror8_2 s9
    slliw s9, s9, 8
    xor \reg, s8, s9
    addw s8, zero, zero # CLEAR
    addw s9, zero, zero # CLEAR
.endm

.macro big_rol_1 reg
    # p1
    andi s8, \reg, 0xFF
    # p2
    srliw s9, \reg, 8
    rol8_1 s8
    rol8_1 s9
    slliw s9, s9, 8
    xor \reg, s8, s9
    addw s8, zero, zero # CLEAR
    addw s9, zero, zero # CLEAR
.endm

.macro big_rol_2 reg
    # p1
    andi s8, \reg, 0xFF
    # p2
    srliw s9, \reg, 8
    rol8_2 s8
    rol8_2 s9
    slliw s9, s9, 8
    xor \reg, s8, s9
    addw s8, zero, zero # CLEAR
    addw s9, zero, zero # CLEAR
.endm

#######################################################################
########################### sbox ######################################
#######################################################################


.global A
.balign 4
A:

    addi sp, sp, -64
    sd ra, 56(sp)  # Use sd for 64-bit ra
    sd fp, 48(sp)  # Use sd for 64-bit fp
    addi fp, sp, 64

    # FIX: Offsets changed from -16.. to -24.. to avoid clobbering saved fp
    sd t0, -24(fp) 
    sd t1, -32(fp)
    sd t2, -40(fp)
    sd t3, -48(fp)

    
    addiw t0, a0, 0 # Use addiw to copy and sign-extend
    addiw t1, a1, 0
    addiw t2, a2, 0
    addiw t3, a3, 0
    addiw a2, t3, 0
    xor a3, t1, t2

    # FIX: Offsets changed
    ld t0, -24(fp) # Use ld to restore
    ld t1, -32(fp)
    ld t2, -40(fp)
    ld t3, -48(fp)

    
    ld ra, 56(sp)  # Use ld to restore
    ld fp, 48(sp)
    addi sp, sp, 64

ret


.global Ap
.balign 4
Ap:

    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    # FIX: Offsets changed
    sd t0, -24(fp)
    sd t1, -32(fp)
    sd t2, -40(fp)
    sd t3, -48(fp)

    addiw t0, a0, 0
    addiw t1, a1, 0
    addiw t2, a2, 0
    addiw t3, a3, 0

    xor a0, t0, t2
    xor a0, a0, t3
    addiw a1, t0, 0
    xor a3, t0, t1

    # FIX: Offsets changed
    ld t0, -24(fp)
    ld t1, -32(fp)
    ld t2, -40(fp)
    ld t3, -48(fp)

    
    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64


ret

.global App
.balign 4
App:

    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    # FIX: Offsets changed
    sd t0, -24(fp)
    sd t1, -32(fp)
    sd t2, -40(fp)
    sd t3, -48(fp)

    addiw t0, a0, 0
    addiw t1, a1, 0
    addiw t2, a2, 0
    addiw t3, a3, 0

    xor a1, t2, t3
    xor a2, t0, t1
    xor a2, a2, t3
    addiw t0, zero, 0xFF # addiw
    slliw t0, t0, 8      # slliw
    xori t0, t0, 0XFF
    xor a2, a2, t0
    xor a3, t2, t0

    # FIX: Offsets changed
    ld t0, -24(fp)
    ld t1, -32(fp)
    ld t2, -40(fp)
    ld t3, -48(fp)

    
    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64

ret


.global App_b
.balign 4
App_b:

    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    # FIX: Offsets changed
    sd t0, -24(fp)
    sd t1, -32(fp)
    sd t2, -40(fp)
    sd t3, -48(fp)

    addiw t0, a0, 0
    addiw t1, a1, 0
    addiw t2, a2, 0
    addiw t3, a3, 0

    xor a1, t2, t3
    xor a2, t0, t1
    xor a2, a2, t3
    addiw a3, t2, 0

    # FIX: Offsets changed
    ld t0, -24(fp)
    ld t1, -32(fp)
    ld t2, -40(fp)
    ld t3, -48(fp)

    
    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64

ret


.global Appp
.balign 4
Appp:

    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    # FIX: Offsets changed
    sd t0, -24(fp)
    sd t1, -32(fp)
    sd t2, -40(fp)
    sd t3, -48(fp)

    addiw t0, a0, 0
    addiw t1, a1, 0
    addiw t2, a2, 0
    addiw t3, a3, 0

    xor a0, t0, t1
    addiw a1, t0, 0
    xor a2, t0, t1
    xor a2, a2, t2
    xor a2, a2, t3

    addiw t0, zero, 0xFF # addiw
    slliw t0, t0, 8      # slliw
    xori t0, t0, 0XFF
    xor a3, t3, t0
    
    # FIX: Offsets changed
    ld t0, -24(fp)
    ld t1, -32(fp)
    ld t2, -40(fp)
    ld t3, -48(fp)

    
    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64
ret

.global Appp_b
.balign 4
Appp_b:

    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    # FIX: Offsets changed
    sd t0, -24(fp)
    sd t1, -32(fp)
    sd t2, -40(fp)
    sd t3, -48(fp)

    addiw t0, a0, 0
    addiw t1, a1, 0
    addiw t2, a2, 0
    addiw t3, a3, 0

    xor a0, t0, t1
    addiw a1, t0, 0
    xor a2, t0, t1
    xor a2, a2, t2
    xor a2, a2, t3

    # FIX: Offsets changed
    ld t0, -24(fp)
    ld t1, -32(fp)
    ld t2, -40(fp)
    ld t3, -48(fp)

    
    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64
ret


#######################################################################
########################### sbox ######################################
#######################################################################


.global sbox
.balign 4
# a0 = shares0 
# a1 = shares1 

sbox:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    # FIX: Offsets changed from -16/-24 to -24/-32
    sd a0, -24(fp) # Save 64-bit pointer
    sd a1, -32(fp) # Save 64-bit pointer

    addw s1, zero, zero # Use addw to clear
    addw s2, zero, zero
    addw s3, zero, zero
    addw s4, zero, zero

    addw t1, zero, zero
    addw t2, zero, zero
    addw t3, zero, zero
    addw t4, zero, zero


    ########################################
    ########################################
    ##### Construct bitsliced format #######
    ########################################
    ########################################



    ########################################
    ############### SHARE A ################
    ########################################

    # ************ S1 REGISTER ************ #


    # FIRST SHARE part 2
    lwu t5, 4(a0) # Use lwu (load word unsigned)

    srliw t0, t5, 28 # Use srliw
    and t0, t0, 0x1
    slliw t0, t0, 8  # Use slliw
    or s1, s1, t0

    srliw t0, t5, 24 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or s1, s1, t0

    srliw t0, t5, 20 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or s1, s1, t0

    srliw t0, t5, 16 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or s1, s1, t0

    srliw t0, t5, 12 
    and t0, t0, 0x1
    slliw t0, t0, 12
    or s1, s1, t0

    srliw t0, t5, 8  
    and t0, t0, 0x1
    slliw t0, t0, 13
    or s1, s1, t0

    srliw t0, t5, 4  
    and t0, t0, 0x1
    slliw t0, t0, 14
    or s1, s1, t0
    

    and t0, t5, 0x1  
    slliw t0, t0, 15
    or s1, s1, t0

    # FIRST SHARE part 1
    lwu t5, 0(a0) # Use lwu

    srliw t0, t5, 28 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or s1, s1, t0

    srliw t0, t5, 24 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or s1, s1, t0

    srliw t0, t5, 20 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or s1, s1, t0

    srliw t0, t5, 16 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or s1, s1, t0

    srliw t0, t5, 12 
    and t0, t0, 0x1
    slliw t0, t0, 4
    or s1, s1, t0

    srliw t0, t5, 8  
    and t0, t0, 0x1
    slliw t0, t0, 5
    or s1, s1, t0

    srliw t0, t5, 4  
    and t0, t0, 0x1
    slliw t0, t0, 6
    or s1, s1, t0
    

    and t0, t5, 0x1  
    slliw t0, t0, 7
    or s1, s1, t0


    # ************ S2 REGISTER ************ #

    # FIRST SHARE part 2
    lwu t5, 4(a0) # Use lwu

    srliw t0, t5, 29 
    and t0, t0, 0x1
    slliw t0, t0, 8
    or s2, s2, t0

    srliw t0, t5, 25 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or s2, s2, t0

    srliw t0, t5, 21 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or s2, s2, t0

    srliw t0, t5, 17 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or s2, s2, t0

    srliw t0, t5, 13 
    and t0, t0, 0x1
    slliw t0, t0, 12
    or s2, s2, t0

    srliw t0, t5, 9  
    and t0, t0, 0x1
    slliw t0, t0, 13
    or s2, s2, t0

    srliw t0, t5, 5  
    and t0, t0, 0x1
    slliw t0, t0, 14
    or s2, s2, t0
    

    srliw t0, t5, 1  
    and t0, t0, 0x1  
    slliw t0, t0, 15
    or s2, s2, t0

    # FIRST SHARE part 1
    lwu t5, 0(a0) # Use lwu

    srliw t0, t5, 29 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or s2, s2, t0

    srliw t0, t5, 25 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or s2, s2, t0

    srliw t0, t5, 21 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or s2, s2, t0

    srliw t0, t5, 17 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or s2, s2, t0

    srliw t0, t5, 13 
    and t0, t0, 0x1
    slliw t0, t0, 4
    or s2, s2, t0

    srliw t0, t5, 9  
    and t0, t0, 0x1
    slliw t0, t0, 5
    or s2, s2, t0

    srliw t0, t5, 5  
    and t0, t0, 0x1
    slliw t0, t0, 6
    or s2, s2, t0
    

    srliw t0, t5, 1  
    and t0, t0, 0x1  
    slliw t0, t0, 7
    or s2, s2, t0

    # ************ S3 REGISTER ************ #

    # FIRST SHARE part 2
    lwu t5, 4(a0) # lwu

    srliw t0, t5, 30 
    and t0, t0, 0x1
    slliw t0, t0, 8
    or s3, s3, t0

    srliw t0, t5, 26 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or s3, s3, t0

    srliw t0, t5, 22 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or s3, s3, t0

    srliw t0, t5, 18 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or s3, s3, t0

    srliw t0, t5, 14 
    and t0, t0, 0x1
    slliw t0, t0, 12
    or s3, s3, t0

    srliw t0, t5, 10 
    and t0, t0, 0x1
    slliw t0, t0, 13
    or s3, s3, t0

    srliw t0, t5, 6  
    and t0, t0, 0x1
    slliw t0, t0, 14
    or s3, s3, t0
    

    srliw t0, t5, 2  
    and t0, t0, 0x1  
    slliw t0, t0, 15
    or s3, s3, t0

    # FIRST SHARE part 1
    lwu t5, 0(a0) # lwu

    srliw t0, t5, 30 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or s3, s3, t0

    srliw t0, t5, 26 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or s3, s3, t0

    srliw t0, t5, 22 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or s3, s3, t0

    srliw t0, t5, 18 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or s3, s3, t0

    srliw t0, t5, 14 
    and t0, t0, 0x1
    slliw t0, t0, 4
    or s3, s3, t0

    srliw t0, t5, 10 
    and t0, t0, 0x1
    slliw t0, t0, 5
    or s3, s3, t0

    srliw t0, t5, 6  
    and t0, t0, 0x1
    slliw t0, t0, 6
    or s3, s3, t0
    

    srliw t0, t5, 2  
    and t0, t0, 0x1  
    slliw t0, t0, 7
    or s3, s3, t0


    # ************ S4 REGISTER ************ #

    # FIRST SHARE part 2
    lwu t5, 4(a0) # lwu

    srliw t0, t5, 31 
    and t0, t0, 0x1
    slliw t0, t0, 8
    or s4, s4, t0

    srliw t0, t5, 27 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or s4, s4, t0

    srliw t0, t5, 23 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or s4, s4, t0

    srliw t0, t5, 19 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or s4, s4, t0

    srliw t0, t5, 15 
    and t0, t0, 0x1
    slliw t0, t0, 12
    or s4, s4, t0

    srliw t0, t5, 11 
    and t0, t0, 0x1
    slliw t0, t0, 13
    or s4, s4, t0

    srliw t0, t5, 7  
    and t0, t0, 0x1
    slliw t0, t0, 14
    or s4, s4, t0
    

    srliw t0, t5, 3  
    and t0, t0, 0x1  
    slliw t0, t0, 15
    or s4, s4, t0

    # FIRST SHARE part 1
    lwu t5, 0(a0) # lwu

    srliw t0, t5, 31 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or s4, s4, t0

    srliw t0, t5, 27 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or s4, s4, t0

    srliw t0, t5, 23 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or s4, s4, t0

    srliw t0, t5, 19 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or s4, s4, t0

    srliw t0, t5, 15 
    and t0, t0, 0x1
    slliw t0, t0, 4
    or s4, s4, t0

    srliw t0, t5, 11 
    and t0, t0, 0x1
    slliw t0, t0, 5
    or s4, s4, t0

    srliw t0, t5, 7  
    and t0, t0, 0x1
    slliw t0, t0, 6
    or s4, s4, t0
    

    srliw t0, t5, 3  
    and t0, t0, 0x1  
    slliw t0, t0, 7
    or s4, s4, t0


    ########################################
    ############### SHARE B ################
    ########################################


    # ************ t1 REGISTER ************ #


    # SECOND SHARE part 2
    lwu t5, 4(a1) # lwu
    

    srliw t0, t5, 23 
    and t0, t0, 0x1
    slliw t0, t0, 8  
    or t1, t1, t0

    srliw t0, t5, 19 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or t1, t1, t0

    srliw t0, t5, 15 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or t1, t1, t0

    srliw t0, t5, 11 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or t1, t1, t0

    srliw t0, t5, 7  
    and t0, t0, 0x1
    slliw t0, t0, 12
    or t1, t1, t0

    srliw t0, t5, 3  
    and t0, t0, 0x1
    slliw t0, t0, 13
    or t1, t1, t0

    srliw t0, t5, 31 
    and t0, t0, 0x1
    slliw t0, t0, 14
    or t1, t1, t0
    

    srliw t0, t5, 27 
    and t0, t0, 0x1  
    slliw t0, t0, 15
    or t1, t1, t0

    # SECOND SHARE part 1
    lwu t5, 0(a1) # lwu
    

    srliw t0, t5, 23 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or t1, t1, t0

    srliw t0, t5, 19 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or t1, t1, t0

    srliw t0, t5, 15 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or t1, t1, t0

    srliw t0, t5, 11 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or t1, t1, t0

    srliw t0, t5, 7  
    and t0, t0, 0x1
    slliw t0, t0, 4
    or t1, t1, t0

    srliw t0, t5, 3  
    and t0, t0, 0x1
    slliw t0, t0, 5
    or t1, t1, t0

    srliw t0, t5, 31 
    and t0, t0, 0x1
    slliw t0, t0, 6
    or t1, t1, t0
    

    srliw t0, t5, 27 
    and t0, t0, 0x1  
    slliw t0, t0, 7
    or t1, t1, t0


    # ************ t2 REGISTER ************ #

    # SECOND SHARE part 2
    lwu t5, 4(a1) # lwu
    

    srliw t0, t5, 24 
    and t0, t0, 0x1
    slliw t0, t0, 8
    or t2, t2, t0

    srliw t0, t5, 20 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or t2, t2, t0

    srliw t0, t5, 16 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or t2, t2, t0

    srliw t0, t5, 12 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or t2, t2, t0

    srliw t0, t5, 8  
    and t0, t0, 0x1
    slliw t0, t0, 12
    or t2, t2, t0

    srliw t0, t5, 4  
    and t0, t0, 0x1
    slliw t0, t0, 13
    or t2, t2, t0

    srliw t0, t5, 0  
    and t0, t0, 0x1
    slliw t0, t0, 14
    or t2, t2, t0
    

    srliw t0, t5, 28 
    and t0, t0, 0x1  
    slliw t0, t0, 15
    or t2, t2, t0

    # SECOND SHARE part 1
    lwu t5, 0(a1) # lwu
    

    srliw t0, t5, 24 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or t2, t2, t0

    srliw t0, t5, 20 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or t2, t2, t0

    srliw t0, t5, 16 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or t2, t2, t0

    srliw t0, t5, 12 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or t2, t2, t0

    srliw t0, t5, 8  
    and t0, t0, 0x1
    slliw t0, t0, 4
    or t2, t2, t0

    srliw t0, t5, 4  
    and t0, t0, 0x1
    slliw t0, t0, 5
    or t2, t2, t0

    srliw t0, t5, 0  
    and t0, t0, 0x1
    slliw t0, t0, 6
    or t2, t2, t0
    

    srliw t0, t5, 28 
    and t0, t0, 0x1  
    slliw t0, t0, 7
    or t2, t2, t0

    # ************ t3 REGISTER ************ #

    # SECOND SHARE part 2
    lwu t5, 4(a1) # lwu
    

    srliw t0, t5, 25 
    and t0, t0, 0x1
    slliw t0, t0, 8
    or t3, t3, t0

    srliw t0, t5, 21 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or t3, t3, t0

    srliw t0, t5, 17 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or t3, t3, t0

    srliw t0, t5, 13 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or t3, t3, t0

    srliw t0, t5, 9  
    and t0, t0, 0x1
    slliw t0, t0, 12
    or t3, t3, t0

    srliw t0, t5, 5  
    and t0, t0, 0x1
    slliw t0, t0, 13
    or t3, t3, t0

    srliw t0, t5, 1  
    and t0, t0, 0x1
    slliw t0, t0, 14
    or t3, t3, t0
    

    srliw t0, t5, 29 
    and t0, t0, 0x1  
    slliw t0, t0, 15
    or t3, t3, t0

    # SECOND SHARE part 1
    lwu t5, 0(a1) # lwu
    

    srliw t0, t5, 25 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or t3, t3, t0

    srliw t0, t5, 21 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or t3, t3, t0

    srliw t0, t5, 17 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or t3, t3, t0

    srliw t0, t5, 13 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or t3, t3, t0

    srliw t0, t5, 9  
    and t0, t0, 0x1
    slliw t0, t0, 4
    or t3, t3, t0

    srliw t0, t5, 5  
    and t0, t0, 0x1
    slliw t0, t0, 5
    or t3, t3, t0

    srliw t0, t5, 1  
    and t0, t0, 0x1
    slliw t0, t0, 6
    or t3, t3, t0
    

    srliw t0, t5, 29 
    and t0, t0, 0x1  
    slliw t0, t0, 7
    or t3, t3, t0


    # ************ t4 REGISTER ************ #

    # SECOND SHARE part 2
    lwu t5, 4(a1) # lwu
    

    srliw t0, t5, 26 
    and t0, t0, 0x1
    slliw t0, t0, 8
    or t4, t4, t0

    srliw t0, t5, 22 
    and t0, t0, 0x1
    slliw t0, t0, 9
    or t4, t4, t0

    srliw t0, t5, 18 
    and t0, t0, 0x1
    slliw t0, t0, 10
    or t4, t4, t0

    srliw t0, t5, 14 
    and t0, t0, 0x1
    slliw t0, t0, 11
    or t4, t4, t0

    srliw t0, t5, 10 
    and t0, t0, 0x1
    slliw t0, t0, 12
    or t4, t4, t0

    srliw t0, t5, 6  
    and t0, t0, 0x1
    slliw t0, t0, 13
    or t4, t4, t0

    srliw t0, t5, 2  
    and t0, t0, 0x1
    slliw t0, t0, 14
    or t4, t4, t0
    

    srliw t0, t5, 30 
    and t0, t0, 0x1  
    slliw t0, t0, 15
    or t4, t4, t0

    # SECOND SHARE part 1
    lwu t5, 0(a1) # lwu
    

    srliw t0, t5, 26 
    and t0, t0, 0x1
    slliw t0, t0, 0
    or t4, t4, t0

    srliw t0, t5, 22 
    and t0, t0, 0x1
    slliw t0, t0, 1
    or t4, t4, t0

    srliw t0, t5, 18 
    and t0, t0, 0x1
    slliw t0, t0, 2
    or t4, t4, t0

    srliw t0, t5, 14 
    and t0, t0, 0x1
    slliw t0, t0, 3
    or t4, t4, t0

    srliw t0, t5, 10 
    and t0, t0, 0x1
    slliw t0, t0, 4
    or t4, t4, t0

    srliw t0, t5, 6  
    and t0, t0, 0x1
    slliw t0, t0, 5
    or t4, t4, t0

    srliw t0, t5, 2  
    and t0, t0, 0x1
    slliw t0, t0, 6
    or t4, t4, t0
    

    srliw t0, t5, 30 
    and t0, t0, 0x1  
    slliw t0, t0, 7
    or t4, t4, t0



    ############################################
    ################# NOW SBOX #################
    ############################################


    ################################# A #################################
    # shares A
    mv a0, s1
    mv a1, s2
    mv a2, s3
    mv a3, s4
    jal A
    mv s1, a0
    mv s2, a1
    mv s3, a2
    mv s4, a3

    # shares B
    mv a0, t1
    mv a1, t2
    mv a2, t3
    mv a3, t4
    jal A
    mv t1, a0
    mv t2, a1
    mv t3, a2
    mv t4, a3

    ################################# Q12 #################################

    ########### PTs(b,a,c) ###########


    and s5, s4, s2 # a0c0
    xor s3, s3, s5 # s3 + a0c0

    ############## s3 + a0c0 + a0c1
    # a0c1
    big_ror_2 s4
    big_ror_1 t2
    and s5, s4, t2
    big_rol_2 s4
    big_rol_1 t2
    big_ror_2 s3
    xor s3, s3, s5
    big_rol_2 s3


    ############## t3 + a1c1
    # a1c1
    and s5, t4, t2
    xor t3, t3, s5
    ############## t3 + a1c1 + a1c0
    # a1c0
    big_ror_2 s2
    big_ror_1 t4
    and s5, s2, t4
    big_rol_2 s2
    big_rol_1 t4
    big_ror_1 t3
    xor t3, t3, s5
    big_rol_1 t3


    ########### PTs(c,a,b) ###########
    ############## s2 + b0c0
    # a0b0
    and s5, s4, s3
    xor s2, s2, s5

    ############## s2 + a0b0 + a0b1
    # a0b1
    big_ror_2 s4
    big_ror_1 t3
    and s5, s4, t3
    big_rol_2 s4
    big_rol_1 t3
    big_ror_2 s2
    xor s2, s2, s5
    big_rol_2 s2

    ############## t2 + a1b1
    # a1b1
    and s5, t4, t3
    xor t2, t2, s5

    ############## t2 + a1b1 + a1b0
    # a1b0
    big_ror_2 s3
    big_ror_1 t4
    and s5, s3, t4
    big_rol_2 s3
    big_rol_1 t4
    big_ror_1 t2
    xor t2, t2, s5
    big_rol_1 t2


    # shares A''
    mv a0, s1
    mv a1, s2
    mv a2, s3
    mv a3, s4
    jal App
    mv s1, a0
    mv s2, a1
    mv s3, a2
    mv s4, a3

    # shares B
    mv a0, t1
    mv a1, t2
    mv a2, t3
    mv a3, t4
    jal App_b
    mv t1, a0
    mv t2, a1
    mv t3, a2
    mv t4, a3


    ################################# A''' #################################
    # shares A
    mv a0, s1
    mv a1, s2
    mv a2, s3
    mv a3, s4
    jal Appp
    mv s1, a0
    mv s2, a1
    mv s3, a2
    mv s4, a3

    # shares B
    mv a0, t1
    mv a1, t2
    mv a2, t3
    mv a3, t4
    jal Appp_b
    mv t1, a0
    mv t2, a1
    mv t3, a2
    mv t4, a3

    ################################# A #################################
    # shares A
    mv a0, s1
    mv a1, s2
    mv a2, s3
    mv a3, s4
    jal A
    mv s1, a0
    mv s2, a1
    mv s3, a2
    mv s4, a3

    # shares B
    mv a0, t1
    mv a1, t2
    mv a2, t3
    mv a3, t4
    jal A
    mv t1, a0
    mv t2, a1
    mv t3, a2
    mv t4, a3


    ################################# Q12 #################################

    ########### PTs(b,a,c) ###########


    and s5, s4, s2 # a0c0
    xor s3, s3, s5 # s3 + a0c0

    ############## s3 + a0c0 + a0c1
    # a0c1
    big_ror_2 s4
    big_ror_1 t2
    and s5, s4, t2
    big_rol_2 s4
    big_rol_1 t2
    big_ror_2 s3
    xor s3, s3, s5
    big_rol_2 s3
    ############## t3 + a1c1
    # a1c1
    and s5, t4, t2
    xor t3, t3, s5
    ############## t3 + a1c1 + a1c0
    # a1c0
    big_ror_2 s2
    big_ror_1 t4
    and s5, s2, t4
    big_rol_2 s2
    big_rol_1 t4
    big_ror_1 t3
    xor t3, t3, s5
    big_rol_1 t3


    ########### PTs(c,a,b) ###########
    ############## s2 + b0c0
    # a0b0
    and s5, s4, s3
    xor s2, s2, s5

    ############## s2 + a0b0 + a0b1
    # a0b1
    big_ror_2 s4
    big_ror_1 t3
    and s5, s4, t3
    big_rol_2 s4
    big_rol_1 t3
    big_ror_2 s2
    xor s2, s2, s5
    big_rol_2 s2

    ############## t2 + a1b1
    # a1b1
    and s5, t4, t3
    xor t2, t2, s5

    ############## t2 + a1b1 + a1b0
    # a1b0
    big_ror_2 s3
    big_ror_1 t4
    and s5, s3, t4
    big_rol_2 s3
    big_rol_1 t4
    big_ror_1 t2
    xor t2, t2, s5
    big_rol_1 t2



    ################################# A'' #################################
    # shares A
    mv a0, s1
    mv a1, s2
    mv a2, s3
    mv a3, s4
    jal App
    mv s1, a0
    mv s2, a1
    mv s3, a2
    mv s4, a3

    # shares B
    mv a0, t1
    mv a1, t2
    mv a2, t3
    mv a3, t4
    jal App_b
    mv t1, a0
    mv t2, a1
    mv t3, a2
    mv t4, a3



    ########################################
    ########################################
    #### Reconstruct registers format ######
    ########################################
    ########################################


    # Share A block 2

    addw t5, zero, zero # addw

    srliw t0, s1, 8 # srliw
    andi t0, t0, 0x1
    slliw t0, t0, 28 # slliw
    xor t5, t5, t0

    srliw t0, s1, 9
    andi t0, t0, 0x1
    slliw t0, t0, 24
    xor t5, t5, t0

    srliw t0, s1, 10
    andi t0, t0, 0x1
    slliw t0, t0, 20
    xor t5, t5, t0

    srliw t0, s1, 11
    andi t0, t0, 0x1
    slliw t0, t0, 16
    xor t5, t5, t0

    srliw t0, s1, 12
    andi t0, t0, 0x1
    slliw t0, t0, 12
    xor t5, t5, t0

    srliw t0, s1, 13
    andi t0, t0, 0x1
    slliw t0, t0, 8
    xor t5, t5, t0

    srliw t0, s1, 14
    andi t0, t0, 0x1
    slliw t0, t0, 4
    xor t5, t5, t0

    srliw t0, s1, 15
    andi t0, t0, 0x1
    xor t5, t5, t0

    srliw t0, s2, 8
    andi t0, t0, 0x1
    slliw t0, t0, 29
    xor t5, t5, t0

    srliw t0, s2, 9
    andi t0, t0, 0x1
    slliw t0, t0, 25
    xor t5, t5, t0

    srliw t0, s2, 10
    andi t0, t0, 0x1
    slliw t0, t0, 21
    xor t5, t5, t0

    srliw t0, s2, 11
    andi t0, t0, 0x1
    slliw t0, t0, 17
    xor t5, t5, t0

    srliw t0, s2, 12
    andi t0, t0, 0x1
    slliw t0, t0, 13
    xor t5, t5, t0

    srliw t0, s2, 13
    andi t0, t0, 0x1
    slliw t0, t0, 9
    xor t5, t5, t0

    srliw t0, s2, 14
    andi t0, t0, 0x1
    slliw t0, t0, 5
    xor t5, t5, t0

    srliw t0, s2, 15
    andi t0, t0, 0x1
    slliw t0, t0, 1
    xor t5, t5, t0


    srliw t0, s3, 8
    andi t0, t0, 0x1
    slliw t0, t0, 30
    xor t5, t5, t0

    srliw t0, s3, 9
    andi t0, t0, 0x1
    slliw t0, t0, 26
    xor t5, t5, t0

    srliw t0, s3, 10
    andi t0, t0, 0x1
    slliw t0, t0, 22
    xor t5, t5, t0

    srliw t0, s3, 11
    andi t0, t0, 0x1
    slliw t0, t0, 18
    xor t5, t5, t0

    srliw t0, s3, 12
    andi t0, t0, 0x1
    slliw t0, t0, 14
    xor t5, t5, t0

    srliw t0, s3, 13
    andi t0, t0, 0x1
    slliw t0, t0, 10
    xor t5, t5, t0

    srliw t0, s3, 14
    andi t0, t0, 0x1
    slliw t0, t0, 6
    xor t5, t5, t0

    srliw t0, s3, 15
    andi t0, t0, 0x1
    slliw t0, t0, 2
    xor t5, t5, t0

    srliw t0, s4, 8
    andi t0, t0, 0x1
    slliw t0, t0, 31
    xor t5, t5, t0

    srliw t0, s4, 9
    andi t0, t0, 0x1
    slliw t0, t0, 27
    xor t5, t5, t0

    srliw t0, s4, 10
    andi t0, t0, 0x1
    slliw t0, t0, 23
    xor t5, t5, t0

    srliw t0, s4, 11
    andi t0, t0, 0x1
    slliw t0, t0, 19
    xor t5, t5, t0

    srliw t0, s4, 12
    andi t0, t0, 0x1
    slliw t0, t0, 15
    xor t5, t5, t0

    srliw t0, s4, 13
    andi t0, t0, 0x1
    slliw t0, t0, 11
    xor t5, t5, t0

    srliw t0, s4, 14
    andi t0, t0, 0x1
    slliw t0, t0, 7
    xor t5, t5, t0

    srliw t0, s4, 15
    andi t0, t0, 0x1
    slliw t0, t0, 3
    xor t5, t5, t0

    # FIX: Restore a0 from its correct stack slot
    ld a0, -24(fp) # ld
    sw t5, 4(a0) # sw is correct (stores lower 32-bits)

    # Share A block 1
    addw t5, zero, zero # addw

    srliw t0, s1, 0
    andi t0, t0, 0x1
    slliw t0, t0, 28
    xor t5, t5, t0

    srliw t0, s1, 1
    andi t0, t0, 0x1
    slliw t0, t0, 24
    xor t5, t5, t0

    srliw t0, s1, 2
    andi t0, t0, 0x1
    slliw t0, t0, 20
    xor t5, t5, t0

    srliw t0, s1, 3
    andi t0, t0, 0x1
    slliw t0, t0, 16
    xor t5, t5, t0

    srliw t0, s1, 4
    andi t0, t0, 0x1
    slliw t0, t0, 12
    xor t5, t5, t0

    srliw t0, s1, 5
    andi t0, t0, 0x1
    slliw t0, t0, 8
    xor t5, t5, t0

    srliw t0, s1, 6
    andi t0, t0, 0x1
    slliw t0, t0, 4
    xor t5, t5, t0

    srliw t0, s1, 7
    andi t0, t0, 0x1
    xor t5, t5, t0

    srliw t0, s2, 0
    andi t0, t0, 0x1
    slliw t0, t0, 29
    xor t5, t5, t0

    srliw t0, s2, 1
    andi t0, t0, 0x1
    slliw t0, t0, 25
    xor t5, t5, t0

    srliw t0, s2, 2
    andi t0, t0, 0x1
    slliw t0, t0, 21
    xor t5, t5, t0

    srliw t0, s2, 3
    andi t0, t0, 0x1
    slliw t0, t0, 17
    xor t5, t5, t0

    srliw t0, s2, 4
    andi t0, t0, 0x1
    slliw t0, t0, 13
    xor t5, t5, t0

    srliw t0, s2, 5
    andi t0, t0, 0x1
    slliw t0, t0, 9
    xor t5, t5, t0

    srliw t0, s2, 6
    andi t0, t0, 0x1
    slliw t0, t0, 5
    xor t5, t5, t0

    srliw t0, s2, 7
    andi t0, t0, 0x1
    slliw t0, t0, 1
    xor t5, t5, t0


    srliw t0, s3, 0
    andi t0, t0, 0x1
    slliw t0, t0, 30
    xor t5, t5, t0

    srliw t0, s3, 1
    andi t0, t0, 0x1
    slliw t0, t0, 26
    xor t5, t5, t0

    srliw t0, s3, 2
    andi t0, t0, 0x1
    slliw t0, t0, 22
    xor t5, t5, t0

    srliw t0, s3, 3
    andi t0, t0, 0x1
    slliw t0, t0, 18
    xor t5, t5, t0

    srliw t0, s3, 4
    andi t0, t0, 0x1
    slliw t0, t0, 14
    xor t5, t5, t0

    srliw t0, s3, 5
    andi t0, t0, 0x1
    slliw t0, t0, 10
    xor t5, t5, t0

    srliw t0, s3, 6
    andi t0, t0, 0x1
    slliw t0, t0, 6
    xor t5, t5, t0

    srliw t0, s3, 7
    andi t0, t0, 0x1
    slliw t0, t0, 2
    xor t5, t5, t0

    srliw t0, s4, 0
    andi t0, t0, 0x1
    slliw t0, t0, 31
    xor t5, t5, t0

Note:
    srliw t0, s4, 1
    andi t0, t0, 0x1
    slliw t0, t0, 27
    xor t5, t5, t0

    srliw t0, s4, 2
    andi t0, t0, 0x1
    slliw t0, t0, 23
    xor t5, t5, t0

    srliw t0, s4, 3
    andi t0, t0, 0x1
    slliw t0, t0, 19
    xor t5, t5, t0

    srliw t0, s4, 4
    andi t0, t0, 0x1
    slliw t0, t0, 15
    xor t5, t5, t0

    srliw t0, s4, 5
    andi t0, t0, 0x1
    slliw t0, t0, 11
    xor t5, t5, t0

    srliw t0, s4, 6
    andi t0, t0, 0x1
    slliw t0, t0, 7
    xor t5, t5, t0

    srliw t0, s4, 7
    andi t0, t0, 0x1
    slliw t0, t0, 3
    xor t5, t5, t0

    # FIX: Restore a0 from its correct stack slot
    ld a0, -24(fp) # ld
    sw t5, 0(a0) # sw

    # SHARES B
    # Share B block 2

    addw t5, zero, zero # addw

    srliw t0, t1, 8
    andi t0, t0, 0x1
    slliw t0, t0, 23
    xor t5, t5, t0

    srliw t0, t1, 9
    andi t0, t0, 0x1
    slliw t0, t0, 19
    xor t5, t5, t0

    srliw t0, t1, 10
    andi t0, t0, 0x1
    slliw t0, t0, 15
    xor t5, t5, t0

    srliw t0, t1, 11
    andi t0, t0, 0x1
    slliw t0, t0, 11
    xor t5, t5, t0

    srliw t0, t1, 12
    andi t0, t0, 0x1
    slliw t0, t0, 7
    xor t5, t5, t0

    srliw t0, t1, 13
    andi t0, t0, 0x1
    slliw t0, t0, 3
    xor t5, t5, t0

    srliw t0, t1, 14
    andi t0, t0, 0x1
    slliw t0, t0, 31
    xor t5, t5, t0

    srliw t0, t1, 15
    andi t0, t0, 0x1
    slliw t0, t0, 27
    xor t5, t5, t0

    srliw t0, t2, 8
    andi t0, t0, 0x1
    slliw t0, t0, 24
    xor t5, t5, t0

    srliw t0, t2, 9
    andi t0, t0, 0x1
    slliw t0, t0, 20
    xor t5, t5, t0

    srliw t0, t2, 10
    andi t0, t0, 0x1
    slliw t0, t0, 16
    xor t5, t5, t0

    srliw t0, t2, 11
    andi t0, t0, 0x1
    slliw t0, t0, 12
    xor t5, t5, t0

    srliw t0, t2, 12
    andi t0, t0, 0x1
    slliw t0, t0, 8
    xor t5, t5, t0

    srliw t0, t2, 13
    andi t0, t0, 0x1
    slliw t0, t0, 4
    xor t5, t5, t0

    srliw t0, t2, 14
    andi t0, t0, 0x1
    slliw t0, t0, 0
    xor t5, t5, t0

    srliw t0, t2, 15
    andi t0, t0, 0x1
    slliw t0, t0, 28
    xor t5, t5, t0


    srliw t0, t3, 8
    andi t0, t0, 0x1
    slliw t0, t0, 25
    xor t5, t5, t0

    srliw t0, t3, 9
    andi t0, t0, 0x1
    slliw t0, t0, 21
    xor t5, t5, t0

    srliw t0, t3, 10
    andi t0, t0, 0x1
    slliw t0, t0, 17
    xor t5, t5, t0

    srliw t0, t3, 11
    andi t0, t0, 0x1
    slliw t0, t0, 13
    xor t5, t5, t0

    srliw t0, t3, 12
    andi t0, t0, 0x1
    slliw t0, t0, 9
    xor t5, t5, t0

    srliw t0, t3, 13
    andi t0, t0, 0x1
    slliw t0, t0, 5
    xor t5, t5, t0

    srliw t0, t3, 14
    andi t0, t0, 0x1
    slliw t0, t0, 1
    xor t5, t5, t0

    srliw t0, t3, 15
    andi t0, t0, 0x1
    slliw t0, t0, 29
    xor t5, t5, t0

    srliw t0, t4, 8
    andi t0, t0, 0x1
    slliw t0, t0, 26
    xor t5, t5, t0

    srliw t0, t4, 9
    andi t0, t0, 0x1
    slliw t0, t0, 22
    xor t5, t5, t0

    srliw t0, t4, 10
    andi t0, t0, 0x1
    slliw t0, t0, 18
    xor t5, t5, t0

    srliw t0, t4, 11
    andi t0, t0, 0x1
    slliw t0, t0, 14
    xor t5, t5, t0

    srliw t0, t4, 12
    andi t0, t0, 0x1
    slliw t0, t0, 10
    xor t5, t5, t0

    srliw t0, t4, 13
    andi t0, t0, 0x1
    slliw t0, t0, 6
    xor t5, t5, t0

    srliw t0, t4, 14
    andi t0, t0, 0x1
    slliw t0, t0, 2
    xor t5, t5, t0

    srliw t0, t4, 15
    andi t0, t0, 0x1
    slliw t0, t0, 30
    xor t5, t5, t0

    # FIX: Restore a1 from its correct stack slot
    ld a1, -32(fp) # ld
    sw t5, 4(a1) # sw

    # Share B block 1
    addw t5, zero, zero # addw

    srliw t0, t1, 0
    andi t0, t0, 0x1
    slliw t0, t0, 23
    xor t5, t5, t0

    srliw t0, t1, 1
    andi t0, t0, 0x1
    slliw t0, t0, 19
    xor t5, t5, t0

    srliw t0, t1, 2
    andi t0, t0, 0x1
    slliw t0, t0, 15
    xor t5, t5, t0

    srliw t0, t1, 3
    andi t0, t0, 0x1
    slliw t0, t0, 11
    xor t5, t5, t0

    srliw t0, t1, 4
    andi t0, t0, 0x1
    slliw t0, t0, 7
    xor t5, t5, t0

    srliw t0, t1, 5
    andi t0, t0, 0x1
    slliw t0, t0, 3
    xor t5, t5, t0

    srliw t0, t1, 6
    andi t0, t0, 0x1
    slliw t0, t0, 31
    xor t5, t5, t0

    srliw t0, t1, 7
    andi t0, t0, 0x1
    slliw t0, t0, 27
    xor t5, t5, t0

    srliw t0, t2, 0
    andi t0, t0, 0x1
    slliw t0, t0, 24
    xor t5, t5, t0

    srliw t0, t2, 1
    andi t0, t0, 0x1
    slliw t0, t0, 20
    xor t5, t5, t0

    srliw t0, t2, 2
    andi t0, t0, 0x1
    slliw t0, t0, 16
    xor t5, t5, t0

    srliw t0, t2, 3
    andi t0, t0, 0x1
    slliw t0, t0, 12
    xor t5, t5, t0

    srliw t0, t2, 4
    andi t0, t0, 0x1
    slliw t0, t0, 8
    xor t5, t5, t0

    srliw t0, t2, 5
    andi t0, t0, 0x1
    slliw t0, t0, 4
    xor t5, t5, t0

    srliw t0, t2, 6
    andi t0, t0, 0x1
    slliw t0, t0, 0
    xor t5, t5, t0

    srliw t0, t2, 7
    andi t0, t0, 0x1
    slliw t0, t0, 28
    xor t5, t5, t0

    srliw t0, t3, 0
    andi t0, t0, 0x1
    slliw t0, t0, 25
    xor t5, t5, t0

    srliw t0, t3, 1
    andi t0, t0, 0x1
    slliw t0, t0, 21
    xor t5, t5, t0

    srliw t0, t3, 2
    andi t0, t0, 0x1
    slliw t0, t0, 17
    xor t5, t5, t0

    srliw t0, t3, 3
    andi t0, t0, 0x1
    slliw t0, t0, 13
    xor t5, t5, t0

    srliw t0, t3, 4
    andi t0, t0, 0x1
    slliw t0, t0, 9
    xor t5, t5, t0

    srliw t0, t3, 5
    andi t0, t0, 0x1
    slliw t0, t0, 5
    xor t5, t5, t0

    srliw t0, t3, 6
    andi t0, t0, 0x1
    slliw t0, t0, 1
    xor t5, t5, t0

    srliw t0, t3, 7
    andi t0, t0, 0x1
    slliw t0, t0, 29
    xor t5, t5, t0

    srliw t0, t4, 0
    andi t0, t0, 0x1
    slliw t0, t0, 26
    xor t5, t5, t0

    srliw t0, t4, 1
    andi t0, t0, 0x1
    slliw t0, t0, 22
    xor t5, t5, t0

    srliw t0, t4, 2
    andi t0, t0, 0x1
    slliw t0, t0, 18
    xor t5, t5, t0

    srliw t0, t4, 3
    andi t0, t0, 0x1
    slliw t0, t0, 14
    xor t5, t5, t0

    srliw t0, t4, 4
    andi t0, t0, 0x1
    slliw t0, t0, 10
    xor t5, t5, t0

    srliw t0, t4, 5
    andi t0, t0, 0x1
    slliw t0, t0, 6
    xor t5, t5, t0

    srliw t0, t4, 6
    andi t0, t0, 0x1
    slliw t0, t0, 2
    xor t5, t5, t0

    srliw t0, t4, 7
    andi t0, t0, 0x1
    slliw t0, t0, 30
    xor t5, t5, t0

    # FIX: Restore a1 from its correct stack slot
    ld a1, -32(fp) # ld
    sw t5, 0(a1) # sw


    # FIX: Restore a0/a1 from stack before epilogue
    ld a0, -24(fp)
    ld a1, -32(fp)

    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64
    ret



.global masked_pLayer_A
.balign 4
masked_pLayer_A:
# a0 = shares A

    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    #load part 1 with lower bits
    lwu s1, 0(a0) # lwu
    #load part 2 with higher bits
    lwu s2, 4(a0) # lwu

    #updated registers
    addw s3, zero, zero # addw
    addw s4, zero, zero # addw


    ############################################ PART 1

    # 0 -> 0
    andi s3, s1, 0x1

    # 1 -> 16
    srliw t0, s1, 1  # srliw
    andi t0, t0, 0x1
    slliw t0, t0, 16 # slliw
    or s3, s3, t0

    # 2 -> 32 % 32 = 0
    srliw t0, s1, 2  
    andi t0, t0, 0x1
    or s4, s4, t0

    # 3 -> 48
    srliw t0, s1, 3  
    andi t0, t0, 0x1
    slliw t0, t0, 16
    or s4, s4, t0

    # 4 -> 1
    srliw t0, s1, 4  
    andi t0, t0, 0x1
    slliw t0, t0, 1
    or s3, s3, t0

    # 5 -> 17
    srliw t0, s1, 5  
    andi t0, t0, 0x1
    slliw t0, t0, 17
    or s3, s3, t0

    # 6 -> 33 % 32 = 1
    srliw t0, s1, 6  
    andi t0, t0, 0x1
    slliw t0, t0, 1
    or s4, s4, t0


                                
    # 7 -> 49 % 32 = 17
    srliw t0, s1, 7  
    andi t0, t0, 0x1
    slliw t0, t0, 17
    or s4, s4, t0


                                
    # 8 -> 2
    srliw t0, s1, 8  
    andi t0, t0, 0x1
    slliw t0, t0, 2
    or s3, s3, t0

    # 9 -> 18
    srliw t0, s1, 9  
    andi t0, t0, 0x1
    slliw t0, t0, 18
    or s3, s3, t0

    # 10 -> 34 % 32 = 2
    srliw t0, s1, 10 
    andi t0, t0, 0x1
    slliw t0, t0, 2
    or s4, s4, t0

    # 11 -> 50 % 32 = 18
    srliw t0, s1, 11 
    andi t0, t0, 0x1
    slliw t0, t0, 18
    or s4, s4, t0

    # 12 -> 3
    srliw t0, s1, 12 
    andi t0, t0, 0x1
    slliw t0, t0, 3
    or s3, s3, t0

    # 13 -> 19
    srliw t0, s1, 13 
    andi t0, t0, 0x1
    slliw t0, t0, 19
    or s3, s3, t0

    # 14 -> 35 % 32 = 3
    srliw t0, s1, 14 
    andi t0, t0, 0x1
    slliw t0, t0, 3
    or s4, s4, t0

    # 15 -> 5 % 32 = 19
    srliw t0, s1, 15 
    andi t0, t0, 0x1
    slliw t0, t0, 19
    or s4, s4, t0

    # 16 -> 4
    srliw t0, s1, 16 
    andi t0, t0, 0x1
    slliw t0, t0, 4
    or s3, s3, t0

    # 17-> 20
    srliw t0, s1, 17 
    andi t0, t0, 0x1
    slliw t0, t0, 20
    or s3, s3, t0


    # 18 -> 36 % 32 = 4
    srliw t0, s1, 18 
    andi t0, t0, 0x1
    slliw t0, t0, 4
    or s4, s4, t0

    # 19 -> 52 % 32 = 20
    srliw t0, s1, 19 
    andi t0, t0, 0x1
    slliw t0, t0, 20
    or s4, s4, t0


    # 20-> 5
    srliw t0, s1, 20 
    andi t0, t0, 0x1
    slliw t0, t0, 5
    or s3, s3, t0


    # 21-> 21
    srliw t0, s1, 21 
    andi t0, t0, 0x1
    slliw t0, t0, 21
    or s3, s3, t0

    # 22 -> 37 % 32 = 5
    srliw t0, s1, 22 
    andi t0, t0, 0x1
    slliw t0, t0, 5
    or s4, s4, t0

    # 23 -> 53 % 32 = 21
    srliw t0, s1, 23 
    andi t0, t0, 0x1
    slliw t0, t0, 21
    or s4, s4, t0

    # 24 -> 6
    srliw t0, s1, 24 
    andi t0, t0, 0x1
    slliw t0, t0, 6
    or s3, s3, t0

    # 25 -> 22
    srliw t0, s1, 25 
    andi t0, t0, 0x1
    slliw t0, t0, 22
    or s3, s3, t0

    # 26 -> 38 % 32 = 6
    srliw t0, s1, 26 
    andi t0, t0, 0x1
    slliw t0, t0, 6
    or s4, s4, t0

    # 27 -> 54 % 32 =22
    srliw t0, s1, 27 
    andi t0, t0, 0x1
    slliw t0, t0, 22
    or s4, s4, t0

    # 28 -> 7
    srliw t0, s1, 28 
    andi t0, t0, 0x1
    slliw t0, t0, 7
    or s3, s3, t0

    # 29 -> 23
    srliw t0, s1, 29 
    andi t0, t0, 0x1
    slliw t0, t0, 23
    or s3, s3, t0

    # 30 -> 39 % 32 = 7
    srliw t0, s1, 30 
    andi t0, t0, 0x1
    slliw t0, t0, 7
    or s4, s4, t0

    # 31 -> 55 % 32 = 23
    srliw t0, s1, 31 
    andi t0, t0, 0x1
    slliw t0, t0, 23
    or s4, s4, t0

    ############################################ PART 2

    # 0 -> 8
    andi t0, s2, 0x1  
    slliw t0, t0, 8
    or s3, s3, t0

    # 1 -> 24
    srliw t0, s2, 1  
    andi t0, t0, 0x1
    slliw t0, t0, 24
    or s3, s3, t0


    # 2 -> 40 % 32 = 8
    srliw t0, s2, 2  
    andi t0, t0, 0x1
    slliw t0, t0, 8
    or s4, s4, t0

    # 3 -> 56 % 32 = 24
    srliw t0, s2, 3  
    andi t0, t0, 0x1
    slliw t0, t0, 24
    or s4, s4, t0

    # 4 -> 9
    srliw t0, s2, 4  
    andi t0, t0, 0x1
    slliw t0, t0, 9
    or s3, s3, t0

    # 5 -> 25
    srliw t0, s2, 5  
    andi t0, t0, 0x1
    slliw t0, t0, 25
    or s3, s3, t0

    # 6 -> 41 % 32 = 9
    srliw t0, s2, 6  
    andi t0, t0, 0x1
    slliw t0, t0, 9
    or s4, s4, t0

    # 7 -> 57 % 32 = 25
    srliw t0, s2, 7  
    andi t0, t0, 0x1
    slliw t0, t0, 25
    or s4, s4, t0

    # 8 -> 10
    srliw t0, s2, 8  
    andi t0, t0, 0x1
    slliw t0, t0, 10
    or s3, s3, t0

    # 9 -> 26
    srliw t0, s2, 9  
    andi t0, t0, 0x1
    slliw t0, t0, 26
    or s3, s3, t0

    # 10 -> 42 % 32 = 10
    srliw t0, s2, 10 
    andi t0, t0, 0x1
    slliw t0, t0, 10
    or s4, s4, t0

    # 11 -> 58 % 32 = 26
    srliw t0, s2, 11 
    andi t0, t0, 0x1
    slliw t0, t0, 26
    or s4, s4, t0

    # 12 -> 11
    srliw t0, s2, 12 
    andi t0, t0, 0x1
    slliw t0, t0, 11
    or s3, s3, t0

    # 13 -> 27
    srliw t0, s2, 13 
    andi t0, t0, 0x1
    slliw t0, t0, 27
    or s3, s3, t0

    # 14 -> 43 % 32 = 11
    srliw t0, s2, 14 
    andi t0, t0, 0x1
    slliw t0, t0, 11
    or s4, s4, t0


    # 15 -> 59 % 32 = 27
    srliw t0, s2, 15 
    andi t0, t0, 0x1
    slliw t0, t0, 27
    or s4, s4, t0


    # 16 -> 12
    srliw t0, s2, 16 
    andi t0, t0, 0x1
    slliw t0, t0, 12
    or s3, s3, t0

    # 17 -> 28
    srliw t0, s2, 17 
    andi t0, t0, 0x1
    slliw t0, t0, 28
    or s3, s3, t0

    # 18 -> 44 % 32 = 12
    srliw t0, s2, 18 
    andi t0, t0, 0x1
    slliw t0, t0, 12
    or s4, s4, t0

    # 19 -> 60 % 32 = 28
    srliw t0, s2, 19 
    andi t0, t0, 0x1
    slliw t0, t0, 28
    or s4, s4, t0

Two:
    srliw t0, s2, 20 
    andi t0, t0, 0x1
    slliw t0, t0, 13
    or s3, s3, t0

    # 21 -> 29
    srliw t0, s2, 21 
    andi t0, t0, 0x1
    slliw t0, t0, 29
    or s3, s3, t0

    # 22 -> 45 % 32 = 13
    srliw t0, s2, 22 
    andi t0, t0, 0x1
    slliw t0, t0, 13
    or s4, s4, t0

    # 23 -> 61 % 32 = 29
    srliw t0, s2, 23 
    andi t0, t0, 0x1
    slliw t0, t0, 29
    or s4, s4, t0

    # 24 -> 14
    srliw t0, s2, 24 
    andi t0, t0, 0x1
    slliw t0, t0, 14
    or s3, s3, t0

    # 25 -> 30
    srliw t0, s2, 25 
    andi t0, t0, 0x1
    slliw t0, t0, 30
    or s3, s3, t0

    # 26 -> 46 % 32 = 14
    srliw t0, s2, 26 
    andi t0, t0, 0x1
    slliw t0, t0, 14
    or s4, s4, t0

    # 27 -> 62 % 32 = 30
    srliw t0, s2, 27 
    andi t0, t0, 0x1
    slliw t0, t0, 30
    or s4, s4, t0

    # 28 -> 15
    srliw t0, s2, 28 
    andi t0, t0, 0x1
    slliw t0, t0, 15
    or s3, s3, t0

    # 29 -> 31
    srliw t0, s2, 29 
    andi t0, t0, 0x1
    slliw t0, t0, 31
    or s3, s3, t0

    # 30 -> 47 % 32 = 15
    srliw t0, s2, 30 
    andi t0, t0, 0x1
    slliw t0, t0, 15
    or s4, s4, t0


    # 31 -> 63 % 32 = 31
    srliw t0, s2, 31 
    andi t0, t0, 0x1
    slliw t0, t0, 31
    or s4, s4, t0


    #store updated part 1 with lower bits
    sw s3, 0(a0) # sw is correct
    #store updated part 2 with higher bits
    sw s4, 4(a0) # sw is correct


    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64
ret



.global masked_pLayer_B
.balign 4
masked_pLayer_B:
# a0 = shares B

    addi sp, sp, -64
    sd ra, 56(sp)
    sd fp, 48(sp)
    addi fp, sp, 64

    #load part 1 with lower bits
    lwu t1, 0(a0) # lwu
    #load part 2 with higher bits
    lwu t2, 4(a0) # lwu

    #updated registers
    addw t3, zero, zero # addw
    addw t4, zero, zero # addw


    ############################################ PART 1
    # place from 31 to 
    srliw t0, t1, 31 # srliw
    andi t0, t0, 0x01
    slliw t3, t0, 31 # slliw


    srliw t0, t2, 28
    andi t0, t0, 0x01
    slliw t0, t0, 30
    or t3, t3, t0

    # 58 mod 32
    srliw t0, t2, 24
    andi t0, t0, 0x01
    slliw t0, t0, 29
    or t3, t3, t0

    # 54 mod 32
    srliw t0, t2, 20
    andi t0, t0, 0x01
    slliw t0, t0, 28
    or t3, t3, t0

    # 50 mod 32
    srliw t0, t2, 16
    andi t0, t0, 0x01
    slliw t0, t0, 27
    or t3, t3, t0

    # 46 mod 32
    srliw t0, t2, 12
    andi t0, t0, 0x01
    slliw t0, t0, 26
    or t3, t3, t0

    # 42 mod 32
    srliw t0, t2, 8
    andi t0, t0, 0x01
    slliw t0, t0, 25
    or t3, t3, t0

    # 38 mod 32
    srliw t0, t2, 4
    andi t0, t0, 0x01
    slliw t0, t0, 24
    or t3, t3, t0

    # 34 mod 32
    srliw t0, t2, 0
    andi t0, t0, 0x01
    slliw t0, t0, 23
    or t3, t3, t0

    # 26 mod 32
    srliw t0, t1, 28
    andi t0, t0, 0x01
    slliw t0, t0, 22
    or t3, t3, t0

    # 22 mod 32
    srliw t0, t1, 24
    andi t0, t0, 0x01
    slliw t0, t0, 21
    or t3, t3, t0

    # 18 mod 32
    srliw t0, t1, 20
    andi t0, t0, 0x01
    slliw t0, t0, 20
    or t3, t3, t0

    # 14 mod 32
    srliw t0, t1, 16
    andi t0, t0, 0x01
    slliw t0, t0, 19
    or t3, t3, t0

    # 10 mod 32
    srliw t0, t1, 12
    andi t0, t0, 0x01
    slliw t0, t0, 18
    or t3, t3, t0

    # 6 mod 32
    srliw t0, t1, 8
    andi t0, t0, 0x01
    slliw t0, t0, 17
    or t3, t3, t0

    # 2 mod 32
    srliw t0, t1, 4
    andi t0, t0, 0x01
    slliw t0, t0, 16
    or t3, t3, t0

    # 61 mod 32
    srliw t0, t1, 0
    andi t0, t0, 0x01
    slliw t0, t0, 15
    or t3, t3, t0

    # 61 mod 32
    srliw t0, t2, 27
    andi t0, t0, 0x01
    slliw t0, t0, 14
    or t3, t3, t0

    # 53 mod 32
    srliw t0, t2, 23
    andi t0, t0, 0x01
    slliw t0, t0, 13
    or t3, t3, t0

    # 49 mod 32
    srliw t0, t2, 19
    andi t0, t0, 0x01
    slliw t0, t0, 12
    or t3, t3, t0

    # 45 mod 32
    srliw t0, t2, 15
    andi t0, t0, 0x01
    slliw t0, t0, 11
    or t3, t3, t0

    # 41 mod 32
    srliw t0, t2, 11
    andi t0, t0, 0x01
    slliw t0, t0, 10
    or t3, t3, t0

    # 37 mod 32
    srliw t0, t2, 7
    andi t0, t0, 0x01
    slliw t0, t0, 9
    or t3, t3, t0

    # 33 mod 32
    srliw t0, t2, 3
    andi t0, t0, 0x01
    slliw t0, t0, 8
    or t3, t3, t0

    # 29 mod 32
    srliw t0, t2, 31
    andi t0, t0, 0x01
    slliw t0, t0, 7
    or t3, t3, t0

    # 25 mod 32
    srliw t0, t1, 27
    andi t0, t0, 0x01
    slliw t0, t0, 6
    or t3, t3, t0

    # 21 mod 32
    srliw t0, t1, 23
    andi t0, t0, 0x01
    slliw t0, t0, 5
    or t3, t3, t0

    # 17 mod 32
    srliw t0, t1, 19
    andi t0, t0, 0x01
    slliw t0, t0, 4
    or t3, t3, t0

    # 13 mod 32
    srliw t0, t1, 15
    andi t0, t0, 0x01
    slliw t0, t0, 3
    or t3, t3, t0

    # 9 mod 32
    srliw t0, t1, 11
    andi t0, t0, 0x01
    slliw t0, t0, 2
    or t3, t3, t0

    # 5 mod 32
    srliw t0, t1, 7
    andi t0, t0, 0x01
    slliw t0, t0, 1
    or t3, t3, t0

    # 1 mod 32
    srliw t0, t1, 3
    andi t0, t0, 0x01
    slliw t0, t0, 0
    or t3, t3, t0


############################################ PART 2
    # place from 31 to 0
    # 60 mod 32
    srliw t0, t1, 1
    andi t0, t0, 0x01
    slliw t4, t0, 31

    # 56 mod 32
    srliw t0, t2, 30
    andi t0, t0, 0x01
    slliw t0, t0, 30
    or t4, t4, t0

    # 52 mod 32
    srliw t0, t2, 26
    andi t0, t0, 0x01
    slliw t0, t0, 29
    or t4, t4, t0

    # 48 mod 32
    srliw t0, t2, 22
    andi t0, t0, 0x01
    slliw t0, t0, 28
    or t4, t4, t0

    # 44 mod 32
    srliw t0, t2, 18
    andi t0, t0, 0x01
    slliw t0, t0, 27
    or t4, t4, t0

    # 40 mod 32
    srliw t0, t2, 14
    andi t0, t0, 0x01
    slliw t0, t0, 26
    or t4, t4, t0

    # 36 mod 32
    srliw t0, t2, 10
    andi t0, t0, 0x01
    slliw t0, t0, 25
    or t4, t4, t0

    # 32 mod 32
    srliw t0, t2, 6
    andi t0, t0, 0x01
    slliw t0, t0, 24
    or t4, t4, t0

    # 28 mod 32
    srliw t0, t2, 2
    andi t0, t0, 0x01
    slliw t0, t0, 23
    or t4, t4, t0

    srliw t0, t1, 30
    andi t0, t0, 0x01
    slliw t0, t0, 22
    or t4, t4, t0

    srliw t0, t1, 26
    andi t0, t0, 0x01
    slliw t0, t0, 21
    or t4, t4, t0

    srliw t0, t1, 22
    andi t0, t0, 0x1
    slliw t0, t0, 20
    or t4, t4, t0

    srliw t0, t1, 18
    andi t0, t0, 0x01
    slliw t0, t0, 19
    or t4, t4, t0

    srliw t0, t1, 14
    andi t0, t0, 0x01
    slliw t0, t0, 18
    or t4, t4, t0

    srliw t0, t1, 10
    andi t0, t0, 0x01
    slliw t0, t0, 17
    or t4, t4, t0

    # 63 mod 32
    srliw t0, t1, 6
    andi t0, t0, 0x01
    slliw t0, t0, 16
    or t4, t4, t0

    # 59 mod 32
    srliw t0, t1, 2
    andi t0, t0, 0x01
    slliw t0, t0, 15
    or t4, t4, t0

    # 55 mod 32
    srliw t0, t2, 29
    andi t0, t0, 0x01
    slliw t0, t0, 14
    or t4, t4, t0

    # 51 mod 32
    srliw t0, t2, 25
    andi t0, t0, 0x01
    slliw t0, t0, 13
    or t4, t4, t0

    # 47 mod 32
    srliw t0, t2, 21
    andi t0, t0, 0x01
    slliw t0, t0, 12
    or t4, t4, t0

    # 43 mod 32
    srliw t0, t2, 17
    andi t0, t0, 0x01
    slliw t0, t0, 11
    or t4, t4, t0

    # 39 mod 32
    srliw t0, t2, 13
    andi t0, t0, 0x01
    slliw t0, t0, 10
    or t4, t4, t0

    # 35 mod 32
    srliw t0, t2, 9
    andi t0, t0, 0x01
    slliw t0, t0, 9
    or t4, t4, t0

    # 31 mod 32
    srliw t0, t2, 5
    andi t0, t0, 0x01
    slliw t0, t0, 8
    or t4, t4, t0

    srliw t0, t2, 1
    andi t0, t0, 0x01
    slliw t0, t0, 7
    or t4, t4, t0

    srliw t0, t1, 29
    andi t0, t0, 0x01
    slliw t0, t0, 6
    or t4, t4, t0

    srliw t0, t1, 25
    andi t0, t0, 0x01
    slliw t0, t0, 5
    or t4, t4, t0

    srliw t0, t1, 21
    andi t0, t0, 0x01
    slliw t0, t0, 4
    or t4, t4, t0

    srliw t0, t1, 17
    andi t0, t0, 0x01
    slliw t0, t0, 3
    or t4, t4, t0

    srliw t0, t1, 13
    andi t0, t0, 0x01
    slliw t0, t0, 2
    or t4, t4, t0

    srliw t0, t1, 9
    andi t0, t0, 0x01
    slliw t0, t0, 1
    or t4, t4, t0

    # 64 mod 32
    srliw t0, t1, 5
    andi t0, t0, 0x01
    slliw t0, t0, 0
    or t4, t4, t0

    #store updated part 1 with lower bits
    sw t3, 0(a0) # sw
    #store updated part 2 with higher bits
    sw t4, 4(a0) # sw
    
    ld ra, 56(sp)
    ld fp, 48(sp)
    addi sp, sp, 64
ret



.global masked_present
.balign 4
masked_present:
# a0 = shares0 (64-bit pointer)
# a1 = shares1 (64-bit pointer)

# a2 = RK_H0 (64-bit pointer)
# a3 = RK_H1 (64-bit pointer)

# a4 = RK_L0 (64-bit pointer)
# a5 = RK_L1 (64-bit pointer)

    # Expanded stack frame for 64-bit registers
    # Need to save: ra(8), fp(8), s10(8), s11(8), s9(8) = 40
    # a0-a5(6*8) = 48
    # Total = 88 bytes. Round to 16-byte alignment = 96 bytes.
    addi sp, sp, -96
    sd ra, 88(sp)
    sd fp, 80(sp)
    addi fp, sp, 96

    addw s10, zero, zero # s10 = loop counter
    addiw s11, zero, 31  # s11 = 31 (rounds)
    addw s9, zero, zero  # s9 = round key offset

    # Save callee-saved registers and arguments
    # Note: -8(fp) and -16(fp) are ra and fp
    sd s10, -24(fp) # sp + 72 
    sd s11, -32(fp) # sp + 64
    sd s9,  -40(fp) # sp + 56

    sd a2, -48(fp)  # sp + 48
    sd a3, -56(fp)  # sp + 40
    sd a4, -64(fp)  # sp + 32
    sd a5, -72(fp)  # sp + 24
    sd a0, -80(fp)  # sp + 16 (shares0)
    sd a1, -88(fp)  # sp + 8  (shares1)


1:
    # Restore pointers for this loop iteration
    # (In case they were clobbered by calls)
    ld a0, -80(fp)
    ld a1, -88(fp)
    ld a2, -48(fp)
    ld a3, -56(fp)
    ld a4, -64(fp)
    ld a5, -72(fp)
    ld s9, -40(fp)

    #################################################################
    ######################### ADD ROUND KEY #########################
    #################################################################


    ################## Update High #################

    lwu s1, 4(a0) # Share A (lwu)
    lwu t1, 4(a1) # Share B (lwu)

    add t0, s9, a2 # 64-bit pointer arithmetic
    lwu s2, 0(t0)  # Share A High Key (lwu)
    add t0, s9, a3 # 64-bit pointer arithmetic
    lwu t2, 0(t0)  # Share B High Key (lwu)

    xor s1, s1, s2
    xor t1, t1, t2

    sw s1, 4(a0) # sw
    sw t1, 4(a1) # sw

    ################## Update LOW #################
    lwu s1, 0(a0) # Share A (lwu)
    lwu t1, 0(a1) # Share B (lwu)


    add t0, s9, a4 # 64-bit pointer arithmetic
    lwu s2, 0(t0)  # Share A Low Key (lwu)
    add t0, s9, a5 # 64-bit pointer arithmetic
    lwu t2, 0(t0)  # Share B Low Key (lwu)

    xor s1, s1, s2
    xor t1, t1, t2

    sw s1, 0(a0) # sw
    sw t1, 0(a1) # sw

    # increase and store in memory offset for round keys array
    addiw s9, s9, 4 # Key array is 32-bit words, so offset is +4 bytes
    sd s9, -40(fp)


    ########################################################
    ######################### SBOX #########################
    ########################################################

    # a0 and a1 are already correct (shares0, shares1 pointers)
    jal sbox
    # SBOX returns values in a0-a3, clobbering our pointers


    # ******************* START OF FIX ******************* #
    
    # We must restore the original pointers before calling
    # the permutation layers.
    ld a0, -80(fp) # Restore pointer to shares0
    ld a1, -88(fp) # Restore pointer to shares1

    # Also restore key pointers, as they are needed for the
    # *next* loop's add_round_key (and sbox clobbered a2-a5)
    ld a2, -48(fp)
    ld a3, -56(fp)
    ld a4, -64(fp)
    ld a5, -72(fp)
    
    # ******************** END OF FIX ******************** #


    #####################################################################
    ######################### Permutation Layer #########################
    #####################################################################

    # a0 now correctly holds the pointer to shares0
    jal masked_pLayer_A

    mv a0, a1            # a0 now gets pointer to shares1
    jal masked_pLayer_B  # a0 correctly holds pointer to shares1
    
    # Restore a0 and a1 for the loop check
    ld a0, -80(fp) 
    ld a1, -88(fp)


    # LOOP ITERATION
    ld s10, -24(fp) 
    ld s11, -32(fp) 
    addiw s10, s10, 1 # addiw
    sd s10, -24(fp) 
    blt s10, s11, 1b


    #############################################################################
    ######################### LAST ADD ROUND KEY RK[31] #########################
    #############################################################################
    
    # Restore pointers for final key addition
    ld a0, -80(fp)
    ld a1, -88(fp)
    ld a2, -48(fp)
    ld a3, -56(fp)
    ld a4, -64(fp)
    ld a5, -72(fp)
    ld s9, -40(fp)

     ################## Update High #################
    lwu s1, 4(a0) # Share A (lwu)
    lwu t1, 4(a1) # Share B (lwu)

    add t0, s9, a2
    lwu s2, 0(t0) # Share A High KEY (lwu)
    add t0, s9, a3
    lwu t2, 0(t0) # Share B High KEY (lwu)

    xor s1, s1, s2
    xor t1, t1, t2

    sw s1, 4(a0) # sw
    sw t1, 4(a1) # sw

    ################## Update LOW #################
    lwu s1, 0(a0) # Share A (lwu)
    lwu t1, 0(a1) # Share B (lwu)


    add t0, s9, a4
    lwu s2, 0(t0) # Share A Low Key (lwu)
    add t0, s9, a5
    lwu t2, 0(t0) # Share B Low Key (lwu)

    xor s1, s1, s2
    xor t1, t1, t2

    sw s1, 0(a0) # sw
    sw t1, 0(a1) # sw
    
    # Restore callee-saved registers
    ld s10, -24(fp)
    ld s11, -32(fp)
    ld s9,  -40(fp)

    # Tear down stack
    ld ra, 88(sp)
    ld fp, 80(sp)
    addi sp, sp, 96

    ret
