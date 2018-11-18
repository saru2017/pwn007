	.intel_syntax noprefix
	.global _start
	.comm buf, 0xAA
_start:
	mov eax, 0x080490e0+8
	mov edx, 0x080490e0
	mov [edx], eax 
	mov eax, 0x0
	mov edx, 0x080490e0+4
	mov [edx], eax 
	mov eax, 0x6e69622f
	mov edx, 0x080490e0+8
	mov [edx], eax 
	mov eax, 0x0068732f
	mov edx, 0x080490e0+12
	mov [edx], eax 
	mov eax, 0xb
	mov ecx, 0x080490e0
	mov edx, 0x0
	mov ebx, 0x080490e0+8
	int 0x00000080
	
