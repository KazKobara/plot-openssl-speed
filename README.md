# How to plot `openssl speed` results (easily)

[日本語 <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/jp.svg" width="20" alt="Japanese" title="Japanese"/>](./README-jp.md)

## Preparation

1. Install necessary commands:
    * On Debian/Ubuntu:

        ```bash
        sudo apt install gnuplot git openssl make gcc gcc-mingw-w64-x86-64
        ```

        > * `openssl` is needed if you use the openssl command in the PATH.
        > * `make gcc` are needed if you `make` openssl commands from the source code.
        > * `gcc-mingw-w64-x86-64` is needed if you make openssl.exe with MinGW.

    * On macOS
      1. Command Line Tools by entering on a terminal a command it provides, such as

          ```zsh
          gcc
          ```

      1. [Homebrew](https://brew.sh/), then

          ```zsh
          brew install gnuplot coreutils
          ```

          > * `coreutils` is needed to use `realpath` command.

      1. Chang the shell to Bash

          ```zsh
          chsh -s /bin/bash
          ```

1. Download scripts:

    ```bash
    git clone https://github.com/KazKobara/plot_openssl_speed.git
    cd plot_openssl_speed
    ```

1. Help and usage:

    ```bash
    ./plot_openssl_speed_all.sh -h
    ```

## Plot `openssl speed` with openssl command in PATH

```bash
./plot_openssl_speed_all.sh -s 1
```

> * The option '`-s 1`' is to set the measuring time to 1 second to speed up and grab the rough trend. Remove it for accurate measurements.
> * The following graphs are obtained without '`-s 1`'.
> * The script ignores '`-s 1`' against LibreSSL since its `openssl speed` does not support `-seconds` option and causes an error at least at 2.8.3.

The measurement results (graph files `*.png` and their data files `*.dat`) are stored in the directories displayed at the end of the output message as follows:

```text
Results are in:
  ./tmp/default_openssl_1.1.1f/graphs/
```

> For WSL (Windows Subsystem for Linux), `/home/` directory of `Ubuntu-20.04` is accessible using File Explore on Windows OS with the following address:

```text
\\wsl$\Ubuntu-20.04\home\
```

Example of graph list (openssl 1.1.1f in PATH):
![graphs](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/all_graphs_1_1_1f.png)

Example of graph list (LibreSSL 2.8.3 in PATH):
![graphs](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/all_graphs_libressl_2_8_3.png)

## Plot speed of openssl's obtained from source code

The following command graphs the speed of openssl command compiled from the source code [tag](https://github.com/openssl/openssl)ed as `openssl-3.0.5`, and openssl.exe command cross-compiled by MinGW (x86_64-w64-mingw32-gcc):

```bash
./plot_openssl_speed_all.sh -s 1 openssl-3.0.5 openssl-3.0.5-mingw
```

> By adding `-mingw` after the tag-name, openssl.exe is cross-compiled by Mingw-w64, and then the results are added on WSL. On the other computational environment, Windows binary executable environment is needed.

Example of graph list (openssl-3.0.5 from source):
![graphs](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/all_graphs_3_0_5.png)

## What graphs show

The processing speed may vary depending on the environment.
The above and the following graphs show the results in the following [computational environment](#computational-environment).

Be careful not to use **broken** or **insufficient-security-level** algorithms even if they are faster than the other.

### Asymmetric-key cryptosystems (digital signatures and key-exchange)

Theoretically, the larger the size, the slower the processing speed, but in practice, some counterexamples exist.
The first examples show the former cases.
The parameter `a` in the line graphs denotes the reduction rate of the processing speed when the size becomes twice where the size is the bit length of the underlying finite field or ring.

RSA:

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/rsa.png" width="300" alt="RSA" title="RSA"/>

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/rsa_sign_fit.png" width="300" alt="RSA" title="RSA"/>
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/rsa_verify_fit.png" width="300" alt="RSA" title="RSA"/>

ECDH (NIST curve over an extension field of Z2):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdh_b.png" width="300" alt="ecdh_b" title="ecdh_b"/>
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdh_b_fit.png" width="300" alt="ecdh_b" title="ecdh_b"/>

ECDH (Brainpool r1 over a prime field):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdh_brp_r1.png" width="300" alt="ecdh_brp" title="ecdh_brp"/>
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdh_brp_r1_fit.png" width="300" alt="ecdh_brp" title="ecdh_brp"/>

The next figures show the counter examples.

ECDSA/ECDH (NIST curve over a prime field, OpenSSL 3.0.5):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdsa_p.png" width="300" alt="ecdsa_p" title="ecdsa_p"/>
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdh_p.png" width="300" alt="ecdh_p" title="ecdh_p"/>

ECDSA (NIST curve over a prime field, LibreSSL 2.8.3):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdsa_p_libre.png" width="300" alt="ecdsa_p_libre" title="ecdsa_p_libre"/>

256-bit is by far faster than the smaller sizes 192-bit and 224-bit, especially for OpenSSL.
It does not mean that 256-bit is exceptional in theory,
but the assembly implementation has tuned it up, since adding `./config` to `-UECP_NISTZ256_ASM` will remove this advantage.
(The processing speed of 384-bit and 521-bit may also be improved in the future depending on the necessity, I think.)

### Hash function SHA/SHS

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/hash.png" width="600" alt="hash" title="hash"/>

API difference:

* When the script invokes the crypt-algorithm with a low-level API, it appends `-no-evp` to the crypt-algorithm name. No difference between APIs.

  > Low-level APIs are deprecated at OpenSSL 3.

Comparison among truncated versions:

* `sha512-224`, `sha512-256`, and `sha384` are truncated versions of `sha512`, so they show almost the same performance.
* In the same way, `sha224` is a truncated version of `sha256`, so they show almost the same performance, too.

Comparison between `sha256` and `sha512`:

* The speed for 16 bytes, or more generally 512-1-64 bits (or 55 bytes) or less, shows the speed of one compression function in both `sha256` and `sha512`. Hence, the figure indicates that one `sha256` compression function is faster than that of `sha512`.
* For more bytes, `sha512` is faster than `sha256` since the number of `sha512` compression-function executions is around half of `sha256` where the input bit length of `sha256` and `sha512`compression functions are 512-bits and 1024-bits, respectively.

SHA-3:

* As shown in the right of the figure, the larger the size, the slower the processing speed among `sha3-*`.
* Compared to `SHA-2`, `SHA-3`(`sha3-*`) are slower due to the larger security margin [[kec17]].

### Symmetric-key cryptosystems and their modes of operation

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/cipher128-256.png" width="600" alt="cipher128-256" title="cipher128-256"/>

In theory:

* Both `AES-*-GCM` and `AES-*-CCM` must be slower than the same key-length `AES-*-CTR` since they are `AES-*-CTR` with their integrity check.
* `AES-*-CCM` must also be slower than `AES-*-CBC`, which is shown in the upper left corner in the above graph list, since the integrity check of `AES-*-CCM` uses the similar algorithm to `AES-*-CBC`.
* `AES-128-*` must be around 1.4 times faster than `AES-256-*` since the number of their rounds are 10 and 14, respectively.

Counter example:

* As shown below, for large inputs, `aes-128-gcm` of LibreSSL (at least 2.8.3) is by far faster than the others.

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/cipher128-256_libre.png" width="600" alt="cipher128-256_libre" title="cipher128-256_libre"/>

### Differences between OpenSSL 1 and 3

* As shown on the right side of `aes128-cbc.png`, `aes-128-cbc-no-evp` (128-bit key AES with the legacy mode of operation, CBC) called by way of the low-level API is slower in OpenSSL 1.1.1 than the high-level API and OpenSSL 3.0.5.

  > Low-level APIs are deprecated at OpenSSL 3.

* Ubuntu 20.04 seems to have tuned the NISTP224 curve up a little (other than the NISTP256 curve) in their default OpenSSL 1.1.1f.

## To change crypt-algorithms to depict

Edit the crypt-algorithm names and the PNG file names in the following area of '`## Edit crypt-algorithms below ##`' in `./plot_openssl_speed_all.sh`:

```bash
    ####################################################################
    ##### Edit crypt-algorithms (and output graph file name) below #####
    ### Asymmetric-key algorithms:
    ###     - All the supported algorithms:
    ${PLOT_SCRIPT} -o "./${GRA_DIR}/rsa.png" rsa
    ${PLOT_SCRIPT} -o "./${GRA_DIR}/dsa.png" eddsa ecdsa dsa
```

For example, changing it as follows saves a graph of measurement results of all the supported `eddsa` and `ecdsa` digital signatures in `ed_ecdsa.png` and its data file in `ed_ecdsa.dat`:

```bash
${PLOT_SCRIPT} -o "./${GRA_DIR}/ed_ecdsa.png" eddsa ecdsa
```

As you can see from the above, `plot_openssl_speed_all.sh` is a wrapper of `${PLOT_SCRIPT}` (`plot_openssl_speed.sh`), and you can directly run it as follows:

```bash
./plot_openssl_speed.sh -o "./tmp/default_openssl_1.1.1f/graphs/ed_ecdsa.png" eddsa ecdsa
```

> where:
>
> * '_1.1.1f' to be changed to the version of the openssl command in PATH.
> * cf. `./plot_openssl_speed.sh -h` for the usage.

If the openssl command specified by the `-p` option either uses shared libraries that is not in the standard library path, or encounters the following errors:

```text
error while loading shared libraries: 
```

```text
symbol lookup error: 
```

add the path to the shared library to `LD_LIBRARY_PATH` (`DYLD_LIBRARY_PATH` for macOS) as follows:

```bash
(export LD_LIBRARY_PATH=./tmp/openssl-3.0.5${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}; ./plot_openssl_speed.sh -p "./tmp/openssl-3.0.5/apps/openssl" -o "./tmp/openssl-3.0.5/graphs/ed_ecdsa.png" eddsa ecdsa)
```

The command `ldd` (or `otool -L` on macOS) shows a list of used shared libraries.

```console
$ ldd ./tmp/openssl-3.0.5/apps/openssl
        libssl.so.3 => not found
        libcrypto.so.3 => not found
```

## Plot using data file

The above scripts also save data, corresponding to the graphs, in files that replaced .png with .dat in the PNG file names.
You can create a new data file by combining the contents of them or by editing them.

You can plot the graph of the edited data file by specifying no crypt-algorithms to the argument (without running `openssl speed`):

```bash
./plot_openssl_speed.sh -d "data_file_to_graph" -o "output_graph_file.png"
```

The data file name is given by any of the following ways:

* With `-d` option
* Without `-d` option:
  * If `-o "output_graph_file.png"` is given, `output_graph_file.dat` is used as the data file.
  * Otherwise, `graph.dat` is used as the data file regarding that the default file `graph.png` is given to `-o`.

You can find the default file names in the 'Usage' shown by:

```console
 plot_openssl_speed.sh -h
 ```

> If `data_file_to_graph` is different from `output_graph_file.dat`,
which is the file name replaced `.png` with `.dat` in `output_graph_file.png`, the `data_file_to_graph` is copied to the `output_graph_file.dat` so that anyone can know that `output_graph_file.dat` is the data file of `output_graph_file.png`.

### Data file format for plot_openssl_speed.sh

* The data separator is (not comma but) space.
* Crypt-algorithm names shall be placed only in the first column.
  * While `openssl speed` outputs some of the crypt-algorithm names in multiple columns, the data file generated by `plot_openssl_speed.sh` automatically aligns them only in the first column.
* The lines starting with \# are comments.
* Do not include double or more consecutive blank lines (after removing the comment lines).
  * Or specify the data block to use with the gnuplot index.
* The number of columns shall be the same throughout a data file except for comment-and-blank lines.
* The number of columns shall be either 3, 5, or 6, which correspond with those of the following `TABLE_TYPE`'s.

> Crypt-algorithms given to the arguments of `plot_openssl_speed.sh` shall be chosen from the same `TABLE_TYPE`'s. Otherwise, it ignores consecutive algorithms with different `TABLE_TYPE`'s.

### "kbytes" TABLE_TYPE

For symmetric-key cryptographies, hash functions, HMACs.

Example:

```text
# type            16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
aes-128-ccm     202973.97k   588256.58k  1065011.71k  1314283.52k  1346633.73k  1381728.26k
hmac(sha512)     23408.12k    90165.99k   249721.98k   538953.37k   756375.73k   782985.02k
sha256           30840.78k    88357.72k   199311.27k   292801.60k   334301.56k   319321.27k
```

### "sig_ver" TABLE_TYPE

For digital signatures.
It graphs the values in the fourth and fifth columns.

Example:

```text
#                   sign      verify     sign/s verify/s
rsa4096             0.003922s 0.000061s   255.0  16471.0
dsa2048             0.000296s 0.000219s  3383.0   4557.0
ecdsa(nistp256)     0.0000s   0.0001s   43201.0  15221.0
EdDSA(Ed25519)      0.0000s   0.0001s   24010.0   8805.0

```

### "op" TABLE_TYPE

For Diffie-Hellman key exchange.
It graphs the values in the third column.

Example:

```text
#               op          op/s
ffdh4096        0.0129s     77.8
ecdh(nistp256)  0.0000s  20643.0
```

## Computational Environment

### WSL2 Ubuntu

```console
$ cat /etc/os-release  | awk '/^PRETTY/ {print substr($0,13)}'

"Ubuntu 20.04.4 LTS"
```

```console
$ uname -srm

Linux 5.10.102.1-microsoft-standard-WSL2 x86_64
```

```console
$ cat /proc/cpuinfo | grep -m 1 "model name" | awk '$1="";$2="";$3=""; {print substr($0,4)}'

Intel(R) Core(TM) i7-10810U CPU @ 1.10GHz
```

Version and configurations of the openssl command in the PATH:

```console
$ openssl version -a

OpenSSL 1.1.1f  31 Mar 2020
built on: Mon Jul  4 11:24:28 2022 UTC
platform: debian-amd64
options:  bn(64,64) rc4(16x,int) des(int) blowfish(ptr)
compiler: gcc -fPIC -pthread -m64 -Wa,--noexecstack -Wall -Wa,--noexecstack -g -O2 -fdebug-prefix-map=/build/openssl-51ig8V/openssl-1.1.1f=. -fstack-protector-strong -Wformat -Werror=format-security -DOPENSSL_TLS_SECURITY_LEVEL=2 -DOPENSSL_USE_NODELETE -DL_ENDIAN -DOPENSSL_PIC -DOPENSSL_CPUID_OBJ -DOPENSSL_IA32_SSE2 -DOPENSSL_BN_ASM_MONT -DOPENSSL_BN_ASM_MONT5 -DOPENSSL_BN_ASM_GF2m -DSHA1_ASM -DSHA256_ASM -DSHA512_ASM -DKECCAK1600_ASM -DRC4_ASM -DMD5_ASM -DAESNI_ASM -DVPAES_ASM -DGHASH_ASM -DECP_NISTZ256_ASM -DX25519_ASM -DPOLY1305_ASM -DNDEBUG -Wdate-time -D_FORTIFY_SOURCE=2
```

Version and configurations of openssl-3.0.5:

```console
$ (export LD_LIBRARY_PATH=./tmp/openssl-3.0.5${LD_LIBRARY_PATH:+:$LD_LIBRARY
_PATH}; ./tmp/openssl-3.0.5/apps/openssl version -a )

OpenSSL 3.0.5 5 Jul 2022 (Library: OpenSSL 3.0.5 5 Jul 2022)
built on: Wed Jul 13 10:43:30 2022 UTC
platform: linux-x86_64
options:  bn(64,64)
compiler: gcc -fPIC -pthread -m64 -Wa,--noexecstack -Wall -O3 -fstack-protector-strong -fstack-clash-protection -fcf-protection -DOPENSSL_USE_NODELETE -DL_ENDIAN -DOPENSSL_PIC -DOPENSSL_BUILDING_OPENSSL -DNDEBUG
```

```console
$ gnuplot -V

gnuplot 5.2 patchlevel 8
```

### macOS

```console
$ uname -srm

Darwin 21.5.0 x86_64
```

```console
$ sysctl machdep.cpu.brand_string

machdep.cpu.brand_string: Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz
```

```console
$ openssl version -a

LibreSSL 2.8.3
options:  bn(64,64) rc4(16x,int) des(idx,cisc,16,int) blowfish(idx) 
```

```console
$ gnuplot -V
gnuplot 5.4 patchlevel 3
```

## Troubleshooting

### libssp-0.dll is missing

Either add the folder of `libssp-0.dll` to the Windows environment PATH, or run the following commands on a WSL Debian/Ubuntu terminal:

```console
sudo apt install gcc-mingw-w64-x86-64
bash
export MINGW_GCC_VER=$(/usr/bin/x86_64-w64-mingw32-gcc-posix --version | awk '/x86_64-w64-mingw32-gcc-posix/ {print substr($3,1,index($3,"-")-1)}')
cp -p  "/usr/lib/gcc/x86_64-w64-mingw32/${MINGW_GCC_VER}-posix/libssp-0.dll" .
exit
```

### Error: bad option or value

Change the options and/or crypt-algorithms given to `openssl speed`.
Some versions of openssl commands do not support them.

## Link

* [[kec17]] [TeamKeccak "Is SHA-3 slow?"][kec17], 2017.6

[kec17]: https://keccak.team/2017/is_sha3_slow.html (TeamKeccak "Is SHA-3 slow?")

---

* [https://github.com/KazKobara/](https://github.com/KazKobara/)
* [https://kazkobara.github.io/ (mostly in Japanese)](https://kazkobara.github.io/)
