;    220b is a JIT compiler for the BF programming language that fits in a bootsector
;    Copyright (C) 2024  Somdipto Chakraborty
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <https://www.gnu.org/licenses/>.

	%define NOPP 0
	BITS 16
	ORG 0x7C00

	PROG_START EQU 0x8000
	TAPE_START EQU PROG_START + 0x0200 + 0x01
	TAPE_END1 EQU TAPE_START + 0x7530
	STACK_TOP EQU TAPE_END1 + 0x0400
	JITDCODE_START EQU STACK_TOP + 0x01

	start:
	XOR AX, AX
	MOV SS, AX
	MOV DS, AX
	MOV ES, AX
	MOV SP, STACK_TOP
	;; read the second sector
	MOV AH, 0x02
	MOV AL, 0x01
	MOV CH, 0x00
	MOV CL, 0x02
	MOV DH, 0x00
	MOV BX, PROG_START
	INT 0x13
	MOV SI, BX		; points to the beginning of the program
	MOV DI, TAPE_START
	MOV BX, TAPE_END1
	.init_ram_loop:
	DEC BX
	MOV BYTE [BX], 0x00
	CMP BX, DI
	JNE .init_ram_loop
	MOV BX, JITDCODE_START

	loop:
	CLD
	LODSB
	MOV CX, 0x09
	.chk_chr:
	MOV DI, CX
	DEC DI
	CMP AL, BYTE [opc_table + DI]
	JE .match
	LOOP .chk_chr
	JMP loop
	.match:
	SHL DI, 0x01
	CALL WORD [op_table + DI]
	JMP loop

	ex_halt:
	MOV WORD [BX], 0xFEEB	; JMP $
	MOV DI, TAPE_START	; this is the tape
	JMP JITDCODE_START

	ex_out:
	MOV WORD [BX], 0x058A	; MOV AL, BYTE [DI]
	MOV WORD [BX + 0x02], 0x0EB4 ; MOV AH, 0x0E
	MOV WORD [BX + 0x04], 0x10CD ; INT 0x10
	ADD BX, 0x06
	RET

	ex_icell:
	MOV WORD [BX], 0x05FE	; INC BYTE [DI]
	INC BX
	INC BX
	RET

	ex_in:
	MOV WORD [BX], 0xE430	; XOR AH, AH
	MOV WORD [BX + 0x02], 0x16CD ; INT 0x16
	MOV WORD [BX + 0x04], 0X0588 ; MOV BYTE [DI], AL
	ADD BX, 0x06
	RET

	ex_dcell:
	MOV WORD [BX], 0x0DFE	; DEC BYTE [DI]
	INC BX
	INC BX
	RET

	ex_icptr:
	MOV BYTE [BX], 0x47 	; INC DI
	INC BX
	RET

	ex_lstart:
	MOV WORD [BX], 0x3D80	   ; ===\
	MOV BYTE [BX + 0x02], 0x00 ; ===/ CMP BYTE [DI], 0x00
	MOV WORD [BX + 0x03], 0x840F ; ====\
	;; MOV WORD [BX + 0x05], DMYS ; ===/ JZ NEAR DMYS
	ADD BX, 0x07
	POP DX
	PUSH BX
	PUSH DX
	RET

	ex_dcptr:
	MOV BYTE [BX], 0x4F	; DEC DI
	INC BX
	RET

	ex_lend:
	POP DX
	POP DI
	PUSH DX
	;; set DMYS
	MOV DX, BX
	ADD DX, 0x07
	SUB DX, DI
	MOV WORD [DI - 0x02], DX
	;; set DMYE
	MOV DX, DI
	SUB DX, BX
	SUB DX, 0x07
	MOV WORD [BX + 0x05], DX
	;;
	MOV WORD [BX], 0x3D80	; =====\
	MOV BYTE [BX + 0x02], 0x00 ; ==/ CMP BYTE [DI], 0x00
	MOV WORD [BX + 0x03], 0x850F ; ===\
	;; MOV WORD [BX + 0x05], DMYE ; ==/ JNZ NEAR DMYE
	ADD BX, 0x07
	RET

	;; jump table
	op_table:
	DW ex_halt, ex_out, ex_icell, ex_in, ex_dcell, ex_icptr, ex_lstart, ex_dcptr, ex_lend

	opc_table:
	DB 0x00, 0x2E, 0x2B, 0x2C, 0x2D, 0x3E, 0x5B, 0x3C, 0x5D
	;;         .    +     ,     -     >      [     <     ]

	%if !NOPP
	TIMES 0x01FE - ($ - $$) DB 0x00
	DB 0x55, 0xAA

	;; the actual program
	DB '-[------->+<]>-.-[->+++++<]>++.+++++++..+++.[->+++++<]>+.------------.--[->++++<]>-.--------.+++.------.--------.-[--->+<]>.', 0x00
	TIMES 0x0400 - ($ - $$) DB 0x00
	%endif
