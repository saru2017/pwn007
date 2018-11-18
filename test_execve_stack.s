	.intel_syntax noprefix
	.comm buf, 0xAA
	.global _start
_start:
	push 0x0068732f
	push 0x6e69622f
	mov ebx, esp
	xor edx, edx
	push edx
	push ebx
	mov eax, 0x0000000b
	mov ecx, esp
	int 0x00000080

	

	
