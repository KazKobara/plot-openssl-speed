# pairing_bench.sh: How to show pairing-benchmarking results easily

[日本語 <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/jp.svg" width="20" alt="Japanese" title="Japanese"/>](./README-pairing-bench-jp.md)

`pairing_bench.sh` measures the processing speed of bilinear maps, or pairings, supported in the following open-source repositories:

* [Relic]
* [Miracle]
* [MCL]

> I chose them because they are active as of `pairing_bench.sh` v1.3 and have already supported or are expected to support more than 128-bit security.

## Examples of measured results

In the legend on the top of the following figures, `loop` denotes the core looping process of the bilinear map, `fexp` denotes final exponentiation, and `pairing` denotes `loop`+`fexp`.

### Comparison per repository

Relic 0.7.0 (`preset/x64-pbc-*.sh` in the Relic 0.7.0 repository)

![relic0.7.0_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/relic0.7.0_time.png)
<!--
![relic0.7.0_time](./figs/pairing/relic0.7.0_time.png)
-->

Miracle v4.1:

![miraclev4.1_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/miraclev4.1_time.png)
<!--
![miraclev4.1_time](./figs/pairing/miraclev4.1_time.png)
-->

MCL 3.04:

Cf. the figure of 128-bit security below.

### Comparison per bit security

128-bit security:

![pairing_128bs_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/pairing_128bs_mclv3.04_relic0.7.0_miraclev4.1_time.png)
<!--
![pairing_128bs_time](./figs/pairing/pairing_128bs_mclv3.04_relic0.7.0_miraclev4.1_time.png)
-->

> For 128-bit security, the results in [[eccbench21]] are useful as well.

192-bit security:

![pairing_192bs_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/pairing_192bs_relic0.7.0_miraclev4.1_time.png)
<!--
![pairing_192bs_time](./figs/pairing/pairing_192bs_relic0.7.0_miraclev4.1_time.png)
-->

> Annex D.3.4 of [[ISO/IEC 15946-5:2022]] gives parameters corresponding to B24-P559, BLS24559, or BLS24_559.

256-bit security:

![pairing_256bs_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/pairing_256bs_relic0.7.0_miraclev4.1_time.png)
<!--
![pairing_256bs_time](./figs/pairing/pairing_256bs_relic0.7.0_miraclev4.1_time.png)
-->

> Annex D.3.5 of [[ISO/IEC 15946-5:2022]] gives parameters corresponding to B48-P581, BLS48581, or BLS48_581.

## How to measure and depict them

1. Install necessary commands:
    * On Debian/Ubuntu:

        ```console
        sudo apt install gnuplot git make gcc python
        ```

        > * `make` and `gcc` are to make binaries in each repository.
        > * `python` is to configure test in Miracle.

<!--
    * On macOS:
      1. Install Command Line Tools

          Follow the instruction after entering a command that Command Line Tools provide like:

          ```zsh
          gcc
          ```

      1. Install [Homebrew](https://brew.sh/), then

          ```zsh
          brew install gnuplot coreutils python
          ```

          > * `coreutils` is needed to use `realpath` command.
          > * `python` is to configure test in Miracle Core.
-->

1. Download and enter this repository:

    ```bash
    git clone https://github.com/KazKobara/plot_openssl_speed.git
    cd plot_openssl_speed
    ```

1. Help and usage:

    ```bash
    ./pairing_bench.sh -h
    ```

1. Command

    The following example command saves measurement raw results, their tailored data, and their figures in the `./tmp/Pairing/` folder as `*.log`, `*.dat`, and `*.png`, respectively.

    ```bash
    ./pairing_bench.sh mcl:v3.04 relic:0.7.0 miracle:v4.1
    ```

    > * The part before `:` in each argument is the alias of the repository supported in this script.
    > * The part after `:` specifies either a branch name or a tag name for that repository.
    > * For x86-based CPUs, `-t tsc` (Time Stamp Counter) option measures CPU cycles using RDTCS/RDTCSP instructions, instead of real time.
    > * For non-x86-based CPUs, you may need to modify `pairing_bensh.sh` and other files according to the instructions in the repository:
    >   * For Relic 0.7.0, change `x64-pbc-*.sh` under `tmp/Pairing/Relic/relic-0.7.0/preset` and adjust `pairing_bensh.sh` for your CPU.

## Computational Environment

I measured and depicted the above figures in the following environment:

### WSL2 Ubuntu

```console
$ awk '/^PRETTY/ {print substr($0,14,length($0)-14)}' /etc/os-release

Ubuntu 22.04.5 LTS
```

```console
$ uname -srm

Linux 6.6.87.2-microsoft-standard-WSL2 x86_64
```

```console
$ awk '{if($1$2 == "modelname"){$1="";$2="";$3=""; model=substr($0,4)}; if($1$2 == "cpuMHz") {max=$4/1000; printf "%s (%.2fGHz)\n",model,max; exit;}}' /proc/cpuinfo

Intel(R) Core(TM) i7-10810U CPU @ 1.10GHz (1.61GHz)
```

<!--
### macOS

```console
$ uname -srm

Darwin 21.5.0 x86_64
```

```console
$ sysctl machdep.cpu.brand_string

machdep.cpu.brand_string: Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz
```
-->

<!--
## Troubleshooting
-->

## Link

* [[Relic]] "Relic Toolkit," [https://github.com/relic-toolkit/relic][relic]
* [[Miracle]] "The MIRACL Core Cryptographic Library," [https://github.com/miracl/core][Miracle]
* [[MCL]] "A portable and fast pairing-based cryptography library," [https://github.com/herumi/mcl](MCL)
* [[eccbench21]] "Benchmarking pairing-friendly elliptic curves libraries," [https://hackmd.io/@gnark/eccbench][eccbench21]
* [[ISO/IEC 15946-5:2022]] "Cryptographic techniques based on elliptic curves - Part 5: Elliptic curve generation," 2022

[Relic]: https://github.com/relic-toolkit/relic (https://github.com/relic-toolkit/relic)
[Miracle]: https://github.com/miracl/core (https://github.com/miracl/core)
[MCL]: https://github.com/herumi/mcl/ (https://github.com/herumi/mcl)
[eccbench21]: https://hackmd.io/@gnark/eccbench (Benchmarking pairing-friendly elliptic curves libraries)

[ISO/IEC 15946-5:2022]: https://www.iso.org/obp/ui/en/#iso:std:iso-iec:15946:-5:ed-3:v1:en ("Information security - Cryptographic techniques based on elliptic curves - Part 5: Elliptic curve generation", 2022)

---

* <https://github.com/KazKobara/>
* <https://kazkobara.github.io/>
