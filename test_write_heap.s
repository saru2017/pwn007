	.intel_syntax noprefix
	.global _start
	.comm buf, 0xAA
_start:
	mov eax, 0x61616161
	mov edx, 0x08049100+0
	mov [edx], eax 
	mov eax, 0x00000061
	mov edx, 0x08049100+4
	mov [edx], eax 
	mov eax, 0x4
	mov ecx, 0x08049100
	mov edx, 0x5
	mov ebx, 0x0
	int 0x00000080
	
