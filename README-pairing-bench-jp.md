# pairing_bench.sh:双線形写像の処理速度を簡単に計測しグラフ描画する方法

[English <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/gb.svg" width="20" alt="English" title="English"/>](./README-pairing-bench.md)

本スクリプトは、ペアリング暗号及び双線形写像の導入、並びに、よりセキュアなパラメータ(192、256ビットセキュリティなど)への移行を検討されている開発者等が、それらの処理速度を手元の環境で計測し、結果を比較表示することにより、導入・移行時の判断材料を得るためのものになります。

v1.3 時点で、以下のオープンソースリポジトリで利用可能な双線形写像（ペアリング）の処理速度を計測し比較結果を図示できます。

* [Relic]
* [Miracle]
* [MCL]

> 更新が続いており、かつ、ビットセキュリティが128より大きなパラメータに対応済み、又は対応が見込まれるリポジトリを選択しています。

## 計測結果の例

以下の図上部の凡例において、`loop`は双線形写像のコア部分を計算するためのループ処理、`fexp`は最終べき乗(Final Exponentiation)、`pairing`は双線形写像全体(`loop`+`fexp`)を表します。

### リポジトリ毎の比較

Relic 0.7.0 (Relic 0.7.0 リポジトリ内の preset/x64-pbc-*.sh):

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

以下の128ビットセキュリティの図をご参照下さい。

### ビットセキュリティ毎の比較

128ビットセキュリティ:

![pairing_128bs_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/pairing_128bs_mclv3.04_relic0.7.0_miraclev4.1_time.png)
<!--
![pairing_128bs_time](./figs/pairing/pairing_128bs_mclv3.04_relic0.7.0_miraclev4.1_time.png)
-->

> 128ビットセキュリティに対しては、[[eccbench21]]の結果も参考になります。

192ビットセキュリティ:

![pairing_192bs_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/pairing_192bs_relic0.7.0_miraclev4.1_time.png)
<!--
![pairing_192bs_time](./figs/pairing/pairing_192bs_relic0.7.0_miraclev4.1_time.png)
-->

> [[ISO/IEC 15946-5:2022]]の Annex D.3.4 では、 B24-P559 、 BLS24559 又は BLS24_559 に相当するパラメータが掲載されています。

256ビットセキュリティ:

![pairing_256bs_time](https://media.githubusercontent.com/media/KazKobara/plot-openssl-speed/main/figs/pairing/pairing_256bs_relic0.7.0_miraclev4.1_time.png)
<!--
![pairing_256bs_time](./figs/pairing/pairing_256bs_relic0.7.0_miraclev4.1_time.png)
-->

> [[ISO/IEC 15946-5:2022]]の Annex D.3.5 では、 B48-P581 、 BLS48581 又は BLS48_581 に相当するパラメータが掲載されています。

## 計測・描画方法

1. 必要なコマンドのインストール
    * Debian/Ubuntu の場合:

        ```console
        sudo apt install gnuplot git make gcc python
        ```

        > * `make` と `gcc` は各リポジトリでのビルドで必要
        > * `python` は Miracle のビルドで必要

<!--
    * macOS の場合:
        1. Command Line Tools のインストール

            ターミナル上で Command Line Tools が提供しているコマンド(例えば以下など)を打ち込み、指示に従う。

            ```zsh
            gcc
            ```

        1. [Homebrew](https://brew.sh/)をインストールし、以下を実行

            ```zsh
            brew install gnuplot coreutils python
            ```

            > * `coreutils` は `realpath` コマンドをインストールするために必要
            > * `python` は Miracle のビルドで必要
-->

1. 本スクリプトのダウンロードとフォルダへの移動

    ```bash
    git clone https://github.com/KazKobara/plot_openssl_speed.git
    cd plot_openssl_speed
    ```

1. ヘルプと使い方の表示

    ```bash
    ./pairing_bench.sh -h
    ```

1. コマンド実行

    以下のコマンド例では、上記のような図を `./tmp/Pairing/` フォルダ内に PNG ファイル(`*.png`)で保存すると共に、その元となった計測結果と計測結果を描画用に整形したデータとを、それぞれ `*.log`、`*.dat` に保存します。

    ```bash
    ./pairing_bench.sh mcl:v3.04 relic:0.7.0 miracle:v4.1
    ```

    > * 各引数の「:」の左側は本コマンドが対応しているリポジトリの略称、右側はそのリポジトリのブランチ又はタグ名になります。
    > * CPUがx86系の場合は `-t tsc` オプションを付加することで（実時間でなく）CPUのRDTCS/RDTCSP命令を用いた Time Stamp Counter 値(単位はcycles) を計測します。
    > * CPUがx86系でない場合は、各リポジトリでの対応状況に応じて、pairing_bensh.sh などの変更が必要となる場合があります。例えば:
    >   * Relic 0.7.0 の場合は、`tmp/Pairing/Relic/relic-0.7.0/preset`フォルダ下の`x64-pbc-*.sh`及び`pairing_bensh.sh`を、そのCPUに対応したものに変更する必要があります。

## 計測環境

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

## リンク

* [[Relic]] "Relic Toolkit", [https://github.com/relic-toolkit/relic][relic]
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
最後までお読み頂きありがとうございます。
GitHubアカウントをお持ちでしたら、フォロー及び Star 頂ければと思います。リンクも歓迎です。

* [Follow (クリック後の画面左)](https://github.com/KazKobara)
* [Star (クリック後の画面右上)](https://github.com/KazKobara/plot-openssl-speed)

[homeに戻る](https://kazkobara.github.io/README-jp.html)
