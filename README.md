# How to plot `openssl speed` results (easily)

[日本語 <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/jp.svg" width="20" alt="Japanese" title="Japanese"/>](./README-jp.md)

* v1.0.0 supports post-quantum cryptographies.

## Preparation

1. Install necessary commands:
    * On Debian/Ubuntu:

        ```bash
        sudo apt install gnuplot git openssl make gcc gcc-mingw-w64-x86-64 cmake ninja autoconf
        ```

        > * `openssl` is for using the openssl command in the PATH.
        > * `make gcc` are for making `openssl` commands from the source code.
        > * `gcc-mingw-w64-x86-64` is for making openssl.exe with MinGW.
        > * `cmake ninja` are for building `oqsprovider` and `liboqs`.
        > * `autoconf` is for making `configure` from `configure.ac` for `LibreSSL` git repo.

    * On macOS
      1. Command Line Tools by entering on a terminal a command it provides, such as

          ```zsh
          gcc
          ```

      1. Install [Homebrew](https://brew.sh/), then

          ```zsh
          brew install gnuplot coreutils mingw-w64 cmake ninja autoconf
          ```

          > * `coreutils` is needed to use `realpath` command.
          > * `mingw-w64` is for building `openssl.exe` with `MinGW`.
          > * `cmake` and `ninja` are for building `oqsprovider`, `liboqs` and so on.
          > * `autoconf` is for making `configure` from `configure.ac` for `LibreSSL` git repo.

      1. If Zsh causes a problem, try changing to Bash

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
    ./plot_openssl_speed.sh -h
    ```

    [Flowcharts](./README-flowchart.md) of these scripts.

1. To compare with PQC data on Web:

    Install [Node.js](https://nodejs.org/) and run:

    ```bash
    cd ./data_from_web/
    npm install --save puppeteer
    npx @puppeteer/browsers install chrome@stable
    cd ..
    ```

    then, run the following scripts.

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

The following command graphs the speed of openssl command compiled from the source code [tag](https://github.com/openssl/openssl)ed as `openssl-3.0.7`, and openssl.exe command cross-compiled by MinGW (x86_64-w64-mingw32-gcc):

```bash
./plot_openssl_speed_all.sh -s 1 openssl-3.0.7 openssl-3.0.7-mingw
```

> * By adding `-mingw` after the tag-name, openssl.exe is cross-compiled by Mingw-w64, and then the results are added on WSL. The other computational environment requires Windows binary executable environment.
> * openssl-3.0.5, shown as an example below, includes [vulnerabilities](https://www.openssl.org/news/vulnerabilities.html). So use a fixed or latest [OpenSSL](https://github.com/openssl/openssl) (or its alternative).

Example of graph list (openssl-3.0.5 from source):
![graphs](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/all_graphs_3_0_5.png)

## Plot speed of post-quantum algorithms

If the openssl command is with liboqs and oqs-provider, `plot_openssl_speed_all.sh` v1.0.0 and newer automatically measure and depict the speed of post-quantum algorithms, too. It also provides comparison graphs of sizes and processing cycles published on [[pq-sig-zoo]] and [[ebats]].

Give the command argument `openssl-type` as follows,
to measure and depict the speed of [openssl](https://github.com/openssl/openssl) with [oqs-provider](https://github.com/open-quantum-safe/oqs-provider/) and [liboqs](https://github.com/open-quantum-safe/liboqs) tagged by `openssl-3.3.1`, `0.6.1`, `0.10.1`, respectively.

```bash
./plot_openssl_speed_all.sh -s 1 openssl-3.3.1-oqsprovider0.6.1-liboqs0.10.1
```

For their master/main branches:

```bash
./plot_openssl_speed_all.sh -s 1 master-oqsprovidermain-liboqsmain
```

> As of v1.0.0, `plot_openssl_speed_all.sh` does not accept `openssl-type` combining `liboqs<tag>-oqsprovider<tag>` with `-mingw`.

## What graphs show

The processing speed may vary depending on the environment.
The above and the following graphs show the results in the following [computational environment](#computational-environment).

Be careful not to use **broken** or **insufficient-security-level** algorithms even if they are faster than the other.

### Post Quantum Cryptography (PQC)

The followings graphs show the processing speeds of PQC's available at OpenSSL 3.4.0-alpha1 with oqs-provider 0.6.1 and liboqs 0.11.0-rc1.

Digital signature:

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/oqs_sig_all.png" width="500" alt="oqs_sig_all" title="oqs_sig_all"/> -->
<img src="./figs/pqc/oqs_sig_all.png" width="500" alt="oqs_sig_all" title="oqs_sig_all"/>

KEM (Key Encapsulation Mechanism):

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/oqs_kem_all.png" width="500" alt="oqs_kem_all" title="oqs_kem_all"/> -->
<img src="./figs/pqc/oqs_kem_all.png" width="500" alt="oqs_kem_all" title="oqs_kem_all"/>

### Comparison between conventional/classical cryptographies and PQC's

[with_webdata.sh](./data_from_web/with_webdata.sh) depicts ciphertext/signature sizes vs. public-key/signature-verification-key sizes as scatter graphs by collecting the necessary size data from [[pq-sig-zoo]] and [[ebats]] and then combining them with other provided data.

#### Digital signatures

Comparison among 128-(classical-)bit security algorithms:

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/sig_128bs.png" width="400" alt="sig_128bs" title="sig_128bs"/> -->
<img src="./figs/pqc/sig_128bs.png" width="400" alt="sig_128bs" title="sig_128bs"/>

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/sig_128bs_size.png" width="400" alt="sig_128bs_size" title="sig_128bs_size"/> -->
<img src="./figs/pqc/sig_128bs_size.png" width="400" alt="sig_128bs_size" title="sig_128bs_size"/>

Comparison among 192-(classical-)bit security algorithms:

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/sig_192bs.png" width="400" alt="sig_192bs" title="sig_192bs"/> -->
<img src="./figs/pqc/sig_192bs.png" width="400" alt="sig_128bs" title="sig_192bs"/>

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/sig_192bs_size.png" width="400" alt="sig_192bs_size" title="sig_192bs_size"/> -->
<img src="./figs/pqc/sig_192bs_size.png" width="400" alt="sig_192bs_size" title="sig_192bs_size"/>

Comparison among 256-(classical-)bit security algorithms:

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/sig_256bs.png" width="400" alt="sig_256bs" title="sig_256bs"/> -->
<img src="./figs/pqc/sig_256bs.png" width="400" alt="sig_128bs" title="sig_256bs"/>

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/sig_256bs_size.png" width="400" alt="sig_256bs_size" title="sig_256bs_size"/> -->
<img src="./figs/pqc/sig_256bs_size.png" width="400" alt="sig_256bs_size" title="sig_256bs_size"/>

#### Key-establishment

One operation of ECDH includes one scalar multiplication to the generator/base-point and one scalar multiplication to a random point.

Comparison among 128-(classical-)bit security level algorithms:

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/dec_enc_keygen_dh_128bs.png" width="400" alt="kem_128bs" title="kem_128bs"/> -->
<img src="./figs/pqc/dec_enc_keygen_dh_128bs.png" width="400" alt="kem_128bs" title="kem_128bs"/>

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/kem_128bs_size.png" width="400" alt="kem_128bs_size" title="kem_128bs_size"/> -->
<img src="./figs/pqc/kem_128bs_size.png" width="400" alt="kem_128bs_size" title="kem_128bs_size"/>

Comparison among 192-(classical-)bit security level algorithms:

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/dec_enc_keygen_dh_192bs.png" width="400" alt="kem_192bs" title="kem_192bs"/> -->
<img src="./figs/pqc/dec_enc_keygen_dh_192bs.png" width="400" alt="kem_192bs" title="kem_192bs"/>

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/kem_192bs_size.png" width="400" alt="kem_192bs_size" title="kem_192bs_size"/> -->
<img src="./figs/pqc/kem_192bs_size.png" width="400" alt="kem_192bs_size" title="kem_192bs_size"/>

Comparison among 256-(classical-)bit security level algorithms:

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/dec_enc_keygen_dh_256bs.png" width="400" alt="kem_256bs" title="kem_256bs"/> -->
<img src="./figs/pqc/dec_enc_keygen_dh_256bs.png" width="400" alt="kem_256bs" title="kem_256bs"/>

<!--
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pqc/kem_256bs_size.png" width="400" alt="kem_256bs_size" title="kem_256bs_size"/> -->
<img src="./figs/pqc/kem_256bs_size.png" width="400" alt="kem_256bs_size" title="kem_256bs_size"/>

### Asymmetric-key cryptosystems (digital signatures and key-establishment)

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

The following figures show the counter examples.

ECDSA/ECDH (NIST curve over a prime field, OpenSSL 3.0.5 source code built and run on Ubuntu 20.04):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdsa_p.png" width="300" alt="ecdsa_p" title="ecdsa_p"/>
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdh_p.png" width="300" alt="ecdh_p" title="ecdh_p"/>

For OpenSSL,

* 256-bit is by far faster than the smaller sizes 192-bit and 224-bit.

  > * It does not mean that 256-bit is exceptional in theory, but the assembly implementation has tuned it up, since adding `-UECP_NISTZ256_ASM` to `./config` will remove this advantage.
  > * The processing speed of 384-bit and 521-bit may also be improved in the future depending on the necessity.

ECDSA/ECDH(NIST curve over a prime field, OpenSSL 3.3.2 of Homebrew on macOS 14.6):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdsa_p_3_3_2brew.png" width="300" alt="ecdsa_p_3_3_2brew" title="ecdsa_p_3_3_2brew"/>
<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/ecdh_p_3_3_2brew.png" width="300" alt="ecdh_p_3_3_2brew" title="ecdh_p_3_3_2brew"/>
<!--
<img src="./figs/ecdsa_p_3_3_2brew.png" width="300" alt="ecdsa_p_3_3_2brew" title="ecdsa_p_3_3_2brew"/>
<img src="./figs/ecdh_p_3_3_2brew.png" width="300" alt="ecdh_p_3_3_2brew" title="ecdh_p_3_3_2brew"/>
-->

* Homebrew's OpenSSL (at least 3.3.1 and 3.3.2 for macOS) and the binary OpenSSL 1.1.1f shipped with Ubuntu 20.04 have tuned up the NISTP224 curve a little in addition to the NISTP256 curve.

ECDSA (NIST curve over a prime field, LibreSSL 2.8.3 shipped with macOS 12.4):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/libressl/ecdsa_p_2_8_3bin.png" width="300" alt="libressl/ecdsa_p_2_8_3bin" title="libressl/ecdsa_p_2_8_3bin"/>

For LibreSSL,

* only the verification speed of 256-bit is faster than the other sizes including the smaller sizes, and
* the signing speeds are slower than their verification ones (from 2.8.0 to at least 3.9.2).

  > * In general, signing speeds are faster than their verification speeds for ECDSA and DSA, and libressl had held this propertiy up to 2.7.4 as shown in the following figure.
  > * [2.8.0 release note](https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-2.8.0-relnotes.txt) says "Added a blinding value when generating DSA and ECDSA signatures, in order to reduce the possibility of a side-channel attack leaking the private key."

ECDSA(NIST curve over a prime field, LibreSSL 2.7.4 source code built and run on macOS 15.0):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/libressl/ecdsa_p_2_7_4.png" width="300" alt="libressl/ecdsa_p_2_7_4" title="libressl/ecdsa_p_2_7_4"/>
<!-- <img src="./figs/libressl/ecdsa_p_2_7_4.png" width="300" alt="libressl/ecdsa_p_2_7_4" title="libressl/ecdsa_p_2_7_4"/> -->

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

* LibreSSL (at least 2.9.1/3.0.0 and newer, and the binaries of 2.8.3 and 3.3.6 shipped with macOS) shows that a part or the whole of `aes-(128|256)-gcm` and `aes-(128|256)-gcm` is by far faster than the others for large-size inputs as follows.

LibreSSL 2.8.3 (shipped with macOS 12.4):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/libressl/cipher128-256_2_8_3bin.png" width="300" alt="libressl/cipher128-256_2_8_3bin" title="libressl/cipher128-256_2_8_3bin"/>
<!--
<img src="./figs/libressl/cipher128-256_2_8_3bin.png" width="300" alt="libressl/cipher128-256_2_8_3bin" title="libressl/cipher128-256_2_8_3bin"/>
-->

LibreSSL 3.3.6 (shipped with macOS 14.6):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/libressl/cipher128-256_3_3_6bin.png" width="300" alt="libressl/cipher128-256_3_3_6bin" title="libressl/cipher128-256_3_3_6bin"/>
<!--
<img src="./figs/libressl/cipher128-256_3_3_6bin.png" width="300" alt="libressl/cipher128-256_3_3_6bin" title="libressl/cipher128-256_3_3_6bin"/>
-->

LibreSSL 3.9.2 (from the source code):

<img src="https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/libressl/cipher128-256_3_9_2.png" width="300" alt="libressl/cipher128-256_3_9_2" title="libressl/cipher128-256_3_9_2"/>
<!--
<img src="./figs/libressl/cipher128-256_3_9_2.png" width="300" alt="libressl/cipher128-256_3_9_2" title="libressl/cipher128-256_3_9_2"/>
-->

### Differences between OpenSSL 1 and 3

* As shown on the right side of `aes128-cbc.png`, `aes-128-cbc-no-evp` (128-bit key AES with the legacy mode of operation, CBC) called by way of the low-level API is slower in OpenSSL 1.1.1 than the high-level API and OpenSSL 3.0.5.

  > * LibreSSL (at least up to 3.9.2) shows the sililar results as OpenSSL 1.
  > * Low-level APIs are deprecated at OpenSSL 3.

## To change crypt-algorithms to depict

Edit the crypt-algorithm names and the PNG file names in the functions `plot_graph_asymmetric()` and `plot_graph_symmetric()` in
`./plot_openssl_speed_all.sh` whereas the former function is for asymmetric-key cryptosystems and the latter is for symmetric-key cryptosystems.

For example, the follows line saves a graph of measurement results of all the supported `eddsa` and `ecdsa` digital signatures in `ed_ecdsa.png`, its plot data in `ed_ecdsa.dat`, and their measurement logs in `eddsa.log` and `ecdsa.log`, respectively:

```bash
${PLOT_SCRIPT} -o "./${GRA_DIR}/ed_ecdsa.png" eddsa ecdsa
```

As you can see from the above, `plot_openssl_speed_all.sh` is a wrapper of `${PLOT_SCRIPT}` (`plot_openssl_speed.sh`), and you can directly run the openssl command in the PATH as follows:

```bash
./plot_openssl_speed.sh -o "./tmp/default_openssl_1.1.1f/graphs/ed_ecdsa.png" eddsa ecdsa
```

> where:
>
> * '_1.1.1f' to be changed to the version of the openssl command in PATH.
> * cf. `./plot_openssl_speed.sh -h` for the usage.

One can specify the openssl command, which is not in the PATH, with `-p` option as follows:

```bash
./plot_openssl_speed.sh -p "./tmp/openssl-3.0.7/apps/openssl" -o "./tmp/openssl-3.0.7/graphs/ed_ecdsa.png" eddsa ecdsa
```

If it encounters the following errors:

```text
error while loading shared libraries: 
```

```text
symbol lookup error: 
```

add the path to the shared library to `LD_LIBRARY_PATH` (`DYLD_LIBRARY_PATH` for macOS) as follows:

```bash
(export LD_LIBRARY_PATH=./tmp/openssl-3.0.7${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}; ./plot_openssl_speed.sh -p "./tmp/openssl-3.0.7/apps/openssl" -o "./tmp/openssl-3.0.7/graphs/ed_ecdsa.png" eddsa ecdsa)
```

The command `ldd` (or `otool -L` on macOS) shows a list of used shared libraries.

```console
$ ldd ./tmp/openssl-3.0.7/apps/openssl
        libssl.so.3 => not found
        libcrypto.so.3 => not found
```

To run the openssl command under a working folder `${TMP}/<openssl-type>` where  `<openssl-type>` includes `<oqsprovider_type>`:

Run the following script once right under the `${TMP}/<openssl-type>` folder:

```bash
../../utils/set_oqsprovider.sh
```

Then, run `../../plot_openssl_speed.sh -p openssl/apps/openssl` in the same folder as follows:

```bash
../../plot_openssl_speed.sh -p openssl/apps/openssl -s 1 -o mldsa44_and_mlkem512.png mldsa44 mlkem512
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
* For v0.0.0, the number of columns shall be the same throughout a data file except for comment-and-blank lines.
  * The versions 1.0.0 and newer allow the combination of the following
    "sig_ver_keygen" and "dec_enc_keygen_dh" TABLE_TYPE's as a "sig_enc_mix" TABLE_TYPE.

> `plot_openssl_speed.sh` ignores and skips consecutive different TABLE_TYPE crypt-algorithms.

### "kbytes" TABLE_TYPE

For symmetric-key cryptographies, hash functions, HMACs.

Example:

```text
# type            16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
aes-128-ccm     202973.97k   588256.58k  1065011.71k  1314283.52k  1346633.73k  1381728.26k
hmac(sha512)     23408.12k    90165.99k   249721.98k   538953.37k   756375.73k   782985.02k
sha256           30840.78k    88357.72k   199311.27k   292801.60k   334301.56k   319321.27k
```

### "sig_ver_keygen" TABLE_TYPE

This TABLE_TYPE is available in v1.0.0 and newer for digital signatures.
Fill `keygen/s` columns of no data with `0`.

> In data-plot mode, `plot_openssl_speed.sh` with `-l TABLE_TYPE` option
> (available in v1.0.0 or newer) accepts the right most consecutive blank
> columns while without the option it guesses the TABLE_TYPE with the number
> of columns.

Example:

```text
# asymmetric_algorithm        sign/s   verify/s   keygen/s
ecdsa(nistp256)              42359.0    15555.0          0
EdDSA(Ed25519)               29607.0     9474.0          0
rsa3072                        553.0    28153.0          0
rsa4096                        268.0    16543.0          0
mldsa44                      14595.0    40081.0    30223.2
```

### "dec_enc_keygen_dh" TABLE_TYPE

This TABLE_TYPE is available in v1.0.0 or newer for DH key exchanges and
symmetric-key cryptographies except digital signatures.
Fill the columns of no data with `0`.

> In data-plot mode, `plot_openssl_speed.sh` with `-l TABLE_TYPE` option
> (available in v1.0.0 or newer) accepts the right most consecutive blank
> columns while without the option it guesses the TABLE_TYPE with the number
> of columns.

Example:

```text
# asymmetric_algorithm         dec/s      enc/s   keygen/s       dh/s
rsa3072                        593.0    26836.0          0          0
rsa4096                        254.0    15503.0          0          0
ecdh(nistp256)                     0          0          0    19963.0
ecdh(X25519)                       0          0          0    30287.0
mlkem512                    114039.0   100366.0    77138.0          0
```

### "sig_enc_mix" TABLE_TYPE

This TABLE_TYPE is available in v1.0.0 and newer for comparison among
"sig_ver_keygen" and "dec_enc_keygen_dh" algorithms.

Example:

```text
# asymmetric_algorithm        sign/s   verify/s   keygen/s
mldsa44                      14595.0    40081.0    30223.2
mldsa65                       8686.0    22795.0    19578.0
mldsa87                       7104.0    14383.0    12445.5
#
# asymmetric_algorithm         dec/s      enc/s   keygen/s       dh/s
mlkem512                    114039.0   100366.0    77138.0          0
mlkem768                     73753.0    71901.0    52051.5          0
mlkem1024                    49803.0    52377.8    43771.7          0
```

### "sig_ver" TABLE_TYPE

For v0.0.0 and digital signatures.
It graphs the values in the fourth and fifth columns.

> Plotting processing times has the following drawbacks:
> It is hard to distinguish the fastest algorithm when
> the comparison set includes slow algorithms.
> Even worse, small processing times are sometimes quantized to
> 0 or the minimal unit.

Example:

```text
#                   sign      verify     sign/s verify/s
rsa4096             0.003922s 0.000061s   255.0  16471.0
dsa2048             0.000296s 0.000219s  3383.0   4557.0
ecdsa(nistp256)     0.0000s   0.0001s   43201.0  15221.0
EdDSA(Ed25519)      0.0000s   0.0001s   24010.0   8805.0

```

### "op" TABLE_TYPE

For v0.0.0 and Diffie-Hellman key exchange.
It graphs the values in the third column.

Example:

```text
#               op          op/s
ffdh4096        0.0129s     77.8
ecdh(nistp256)  0.0000s  20643.0
```

### Data file format for with_webdata.sh

`./data_from_web/with_webdata.sh -d <filename>.dat` command reads this data file where:

* The data separator is (not comma but) space.
* The lines starting with \# are comments.
* Do not include double or more consecutive blank lines (after removing the comment lines).
  * Or specify the data block to use with the gnuplot index.

Example:

```text
# x min      25%        50%        75%        max (k|s|v|d|e):name(source)             parameter
# x dummy    25%        50%        75%      dummy (k|s|v|d|e):'25/50/75% are given'    parameter
# x dummy  dummy       mean      dummy      dummy (k|s|v|d|e):'only the mean is given' parameter
  1 0      76090      86116     134869     134869 s:dilithium2aes(ebats-ryzen7)           2
  2 0      42770      42987      43140      43140 v:dilithium2aes(ebats-ryzen7)           2
  3 0      33094      33541      33924      33924 k:dilithium2aes(ebats-ryzen7)           2
  4 0      74124      74124      74124      74124 s:mldsa44(liboqs0.10.1)                44
  5 0    31584.7    31584.7    31584.7    31584.7 v:mldsa44(liboqs0.10.1)                44
  6 0    35220.3    35220.3    35220.3    35220.3 k:mldsa44(liboqs0.10.1)                44
  7 0     333013     333013     333013     333013 s:ML-DSA-44(pq-sig-zoo)                44
  8 0     118412     118412     118412     118412 v:ML-DSA-44(pq-sig-zoo)                44
```

Each column shows:

* 1st column:
  * `x-axis` to plot the data in the line.
* 2nd to 6th columns:
  * Cycles to execute the algorithm of `min`, `25%`, `50%/mean`, `75%`, `max` values, respectively.
  * [ECRYPT Benchmarking](https://bench.cr.yp.to/) provides `25%`, `50%`, `75%` values. Set them there and put dummy values to min and max.
  * If only the mean value is available, set it to `50%/mean` and put dummy values in the other columns.
* 7th column:
  * The name to be shown on the x-axis.
  * The leading `k:`, `s:`, `v:`, `e:`, `d:` in the name represent the operation type of keygen, sign, verification, encryption/encapsulation, decryption/decapsulation, respectively.
  * The string in `()` represents the data source.
* 8th column:
  * Parameter extracted from the name.
  * While this column is for sorting lines, `with_webdata.sh` does not use it as of v1.0.0. So, you may put a dummy value (but not blank) here.

## Computational Environment

### WSL2 Ubuntu

```console
$ awk '/^PRETTY/ {print substr($0,14,length($0)-14)}' /etc/os-release

"Ubuntu 20.04.4 LTS"
```

```console
$ uname -srm

Linux 5.10.102.1-microsoft-standard-WSL2 x86_64
```

```console
$ awk '$1$2 == "modelname" {$1="";$2="";$3=""; print substr($0,4); exit;}' /proc/cpuinfo

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

### ./apps/openssl.exe: Invalid argument

Check if your security software displays a message that blocks the execution. If so, unblock it and run the same script again.

## Link

* [[kec17]] [TeamKeccak "Is SHA-3 slow?"][kec17], 2017.6
* [[pq-sig-zoo]] ["Post-Quantum signatures zoo"][pq-sig-zoo]
* [[ebats]] ["eBATS: ECRYPT Benchmarking of Asymmetric Systems"][ebats]

[kec17]: https://keccak.team/2017/is_sha3_slow.html (TeamKeccak "Is SHA-3 slow?")
[pq-sig-zoo]: https://pqshield.github.io/nist-sigs-zoo/ "Post-Quantum signatures zoo"
[ebats]: https://bench.cr.yp.to/ebats.html "eBATS: ECRYPT Benchmarking of Asymmetric Systems"

## Acknowledgments

---

* <https://github.com/KazKobara/>
* <https://kazkobara.github.io/>
