# PWNオーバーフロー入門: Return-Oriented-Programming (SSP、ASLR、PIE無効で32bit ELF)

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
0xfffffff4: 0x68732f2f # "//sh"
0xfffffff8: 0x1
0xfffffffc: [関係なし]
```

レジスタの状態は

```
eax: 0x0b
ebx: 0xfffffff0 #"/bin//sh"が書かれているアドレス
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
0xfffffff4: 0x68732f2f # "//sh"
0xfffffff8: [関係なし]
0xfffffffc: [関係なし]
```

レジスタの状態は

```
eax: 0x0000000b #超重要！システムコールexecveを示す番号11
ebx: [関係なし] #スタックに積むように一時的に使って他だけ
ecx: 0xffffffe8 #スタックのトップのアドレス
edx: 0x00000000 #重要そう！わざわざedxをゼロにしているところがある
esi: [関係なし]
edi: [関係なし]
ebp: 0x00000000 #たぶん関係ない 
esp: 0xffffffe8 #スタックのトップのアドレス
eip: [関係なし]
```




## libcの中の必要なアドレスを調べる

libcの中から「retで終わる」かつ「必要なコマンドがretの前にある」部分を探していく。


