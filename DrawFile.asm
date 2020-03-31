#######################################################################
# Created By: Robinson, Sidney
#        
#             8 March 2020
#
# Description: implement functions that perform some primitive 
# graphics operations on a small simulated display
#
# Notes: This program is intended to be run from the MARS IDE
######################################################################
######################################################################

# Macro that stores the value in %reg on the stack 
#  and moves the stack pointer.
.macro push(%reg)
subi $sp,$sp,4 #moves the stack pointer down
sw %reg,($sp) #stores the reg word at that pointer address
.end_macro 

# Macro takes the value on the top of the stack and 
#  loads it into %reg then moves the stack pointer.
.macro pop(%reg)
lw %reg, ($sp)    # Load $t0 from top of stack
addi $sp, $sp, 4 # Move stack pointer up
.end_macro

# Macro that takes as input coordinates in the format
# (0x00XX00YY) and returns 0x000000XX in %x and 
# returns 0x000000YY in %y
.macro getCoordinates(%input %x %y) #apply a transformation to input to issolate input using a shift Bitshift of 2
srl %x,%input,16 #does a bitwise shift 4 right to isolate x's 00XX00YY->000000XX
sll %y,%input,16 #does a bitwise shift 4 left to isolate y's 00XX00YY->00YY0000
rol %y,%y,16 #does a bitwise rotate to get y into it's proper place 00YY0000->000000YY
.end_macro

# Macro that takes Coordinates in (%x,%y) where
# %x = 0x000000XX and %y= 0x000000YY and
# returns %output = (0x00XX00YY)
.macro formatCoordinates(%output %x %y) #apply the opositieshift transformation to input to issolate input using a shift
la %output, ($zero) #zeroing out the output (Do I need to do that?)
or %output,%output,%x # adds 000000XX to output
sll %output,%output,16 #shifts the output left by four resulting in the format 00XX0000
or %output,%output,%y #adds the bits of %y into output -> 00XX00YY
.end_macro 


.data
originAddress: .word 0xFFFF0000
.text
#######################Clear Bitmap Test
#li $a0, 0x00003F00
#jal clear_bitmap
######################End Clear Bitmap Test

#####################Draw Pixel Test
# $a0 = coordinates of pixel in format (0x00XX00YY)
# $a1 = color of pixel
#li $a0 0x00020004
#li $a1 0x00FF0000
#jal draw_pixel
#####################End Draw Pixel Test

##################### GET PIXEL TEST
# $a0 = coordinates of pixel in format (0x00XX00YY)
# $a1 = color of pixel
#li $a0 0x00010003
#jal get_pixel
#####################End  GET PIXEL TEST

#####################Draw Line Test
	#li $a0 0x0020000A
	#li $a1 0x007A000A
	#li $a2 0x00FF0000
	#jal draw_line
	
#####################DEnd raw Line Test
#############################Draw Triangle Test
	#li $a0 0x0021005F
	#li $a1 0x00400021
 	#li $a2 0x005F005F
	#li $a3 0
	#jal draw_triangle
#################################End Draw Triangle
j done
    
    done: nop
    li $v0 10 # termination of program
    syscall   # syscall

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#  Subroutines defined below
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#*****************************************************
# clear_bitmap:
#  Given a color in $a0, sets all pixels in the display to
#  that color.	
#-----------------------------------------------------
# $a0 =  color of pixel
#*****************************************************
clear_bitmap: nop
li $t0,0 #initializing counter
clearLoop:
li $t1,4 #load 4 into an immediate
li $t2,0 #resetinng the t2 for each iteration
lw $t3,originAddress #loading the originAddress into t3
beq $t0,16384,endClearLoop #at the end of the loop branch out #128x128
mul $t2,$t0,$t1 #storing in t1 the result of the counter multipliied by 4
add $t2,$t3,$t2  #0xffff000 + counter * 4
sw $a0,($t2) #storing the color into the pixel
addi $t0,$t0,1 #using t0 as a counter
b clearLoop
endClearLoop:	
	jr $ra
	
#*****************************************************
# draw_pixel:
#  Given a coordinate in $a0, sets corresponding value
#  in memory to the color given by $a1
#  [(row * row_size) + column] to locate the correct pixel to color
#-----------------------------------------------------
# $a0 = coordinates of pixel in format (0x00XX00YY)
# $a1 = color of pixel
#*****************************************************
draw_pixel: nop
getCoordinates($a0 $t0 $t1)
bgt $t0,127,endCheck
bgt $t1,127,endCheck
li $t2,128 #storing the row size 128 into t2
mul $t1,$t1,$t2 #multiplying the row by the row size
add $t0,$t0,$t1 #+ column
mul $t0,$t0,4
#$t0 now represents the index
#t0 is not the proper index
lw $t3, originAddress #proper index of pixel in the array + starting index = proper index
add $t3,$t0,$t3 #setting $t0 to the proper place in the array
sw $a1,($t3) #storing the color into the effectuve address
endCheck:
	jr $ra
#*****************************************************
# get_pixel:
#  Given a coordinate, returns the color of that pixel	
#-----------------------------------------------------
# $a0 = coordinates of pixel in format (0x00XX00YY)
# returns pixel color in $v0	
#*****************************************************
#do i want to bit shift by 2 to get it to the proper place?
get_pixel: nop
getCoordinates($a0 $t0 $t1)
   #index = y *width + x
   li $t2,128 #storing width
   mul $t2,$t1,$t2 #multiplying y * width
   add $t2,$t2,$t0 # adding x
   mul $t2,$t2,4
   #that should give index
   lw $t3,originAddress #storing the address of $a0 which is the coordinate
   add $t3,$t3,$t2
   lw $v0,($t3) #end goal you want to store it into v0
	jr $ra

#***********************************************
# draw_line:
#  Given two coordinates, draws a line between them 
#  using Bresenham's incremental error line algorithm	
#-----------------------------------------------------
# 	Bresenham's line algorithm (incremental error)
# plotLine(int x0, int y0, int x1, int y1)
#    dx =  abs(x1-x0);
#    sx = x0<x1 ? 1 : -1;
#    dy = -abs(y1-y0);
#    sy = y0<y1 ? 1 : -1;
#    err = dx+dy;  /* error value e_xy */
#    while (true)   /* loop */
#        plot(x0, y0);
#        if (x0==x1 && y0==y1) break;
#        e2 = 2*err;
#        if (e2 >= dy) 
#           err += dy; /* e_xy+e_x > 0 */
#           x0 += sx;
#        end if
#        if (e2 <= dx) /* e_xy+e_y < 0 */
#           err += dx;
#           y0 += sy;
#        end if
#   end while
#-----------------------------------------------------
# $a0 = first coordinate (x0,y0) format: (0x00XX00YY)
# $a1 = second coordinate (x1,y1) format: (0x00XX00YY)
# $a2 = color of line format: (0x00RRGGBB)
#***************************************************
draw_line: nop

getCoordinates($a0 $t0 $t1)
getCoordinates($a1 $t2 $t3)
move $a1,$a2



sub $t4,$t2,$t0
abs $t4,$t4
#t4 is dx

sub $t5,$t3,$t1
abs $t5,$t5
not $t5,$t5
addi $t5, $t5, 1
#t5 is my dy

blt $t0,$t2,sxone
bge $t0,$t2,sxnegone
sxone:
li $t6,1
j endOfCheck1

sxnegone:
li $t6,-1
endOfCheck1:
#t6 is my sx


blt $t1,$t3,syone
bge $t1,$t3,synegone
syone:
li $t7,1
j endOfCheck2

synegone:
li $t7,-1
endOfCheck2:
#t7 is sy



add $t8,$t5,$t4
#t8 is my err


push($ra)
whileLoop:
bgt $t0,127,endWhileLoop
bgt $t1,127,endWhileLoop
formatCoordinates($a0 $t0 $t1)
push($t0)
push($t1)
push($t2)
push($t3)
push($t4)
jal draw_pixel #plot
pop($t4)
pop($t3)
pop($t2)
pop($t1)
pop($t0)

bne $t0,$t2,endOfCheck
beq $t1,$t3,endWhileLoop
endOfCheck:

mul $t9,$t8,2 # e2 is 2*err

bge $t9,$t5, firstIf #e2 >= dy
b endFirstIf
firstIf:
add $t8,$t8,$t5 #err += dy
add $t0,$t0,$t6 #x0 += sx
endFirstIf:

ble $t9,$t4,secondIf #e2 <= dx
b endSecondIf
secondIf:
add $t8,$t8,$t4 # err+=dx
add $t1,$t1,$t7 # y0 += sy

endSecondIf:

b whileLoop
endWhileLoop:
pop($ra)
	jr $ra
	
#*****************************************************
# draw_rectangle:
#  Given two coordinates for the upper left and lower 
#  right coordinate, draws a solid rectangle	
#-----------------------------------------------------
# $a0 = first coordinate (x0,y0) format: (0x00XX00YY)
# $a1 = second coordinate (x1,y1) format: (0x00XX00YY)
# $a2 = color of line format: (0x00RRGGBB)
#***************************************************
draw_rectangle: nop
getCoordinates($a0,$t0,$t1)
getCoordinates($a1,$t2,$t3)
move $t4,$t3 #store end point in a temp
#	li $a0 0x00200020
#    	li $a1 0x00600060
BasicLoop:
bgt $t1,$t4,EndBasicLoop #if y0 equals y1 after the last draw
formatCoordinates($a1,$t2,$t1) #changing coordinates to make it a level horizontal line when drawn
push($ra)
push($t0)
push($t1)
push($t2)
push($t3)
push($t4)
jal draw_line #plotting line
pop($t4)
pop($t3)
pop($t2)
pop($t1)
pop($t0)
pop($ra)
addi $t1,$t1,1 #move the y down by `
formatCoordinates($a0,$t0,$t1) #reformating our first coordinate
b BasicLoop
EndBasicLoop:

	jr $ra
	
#*****************************************************
#Given three coordinates, draws a triangle
#-----------------------------------------------------
# $a0 = coordinate of point A (x0,y0) format: (0x00XX00YY)
# $a1 = coordinate of point B (x1,y1) format: (0x00XX00YY)
# $a2 = coordinate of traingle point C (x2, y2) format: (0x00XX00YY)
# $a3 = color of line format: (0x00RRGGBB)
#-----------------------------------------------------
# Traingle should look like:
#               B
#             /   \
#            A --  C
#***************************************************	
draw_triangle: nop
push($ra)
push($a0)
push($a1)
push($a2)
push($a3)
move $a2,$a3  #shifting color into proper register for draw line
jal draw_line #drawing A to B
pop($a3)
pop($a2)
pop($a1)
pop($a0)
pop($ra)


push($ra)
push($a0)
push($a1)
push($a2)
push($a3)
move $a0,$a0  #resseting a0 A
move $a1,$a2  #moving a2 into aka C
move $a2,$a3  #shifting color into proper register for draw line
jal draw_line # Drawing A to C
pop($a3)
pop($a2)
pop($a1)
pop($a0)
pop($ra)



push($ra)
push($a0)
push($a1)
push($a2)
push($a3)
move $a0,$a1 # setting a0 to B
move $a1,$a2 # setting a1 to C
move $a2,$a3 #shifting color into proper register for draw line
jal draw_line #Drawing B to C
pop($a3)
pop($a2)
pop($a1)
pop($a0)
pop($ra)





	jr $ra	
	
	
	
