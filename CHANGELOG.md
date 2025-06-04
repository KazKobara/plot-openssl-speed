# Change Log

All notable changes, such as backward incompatibilities, will be documented in this file.

<!-- markdownlint-disable MD024 no-duplicate-heading -->

<!-- ## [Unreleased 1.2.2] -->

## [1.2.1]

### Added

- [A patch](./utils/speed_pqcsigs_in_default_provider.patch) to fix [this error](https://github.com/openssl/openssl/issues/27108).
- How to troubleshoot `TimeoutError: Navigation timeout of` in README.

### Changed

- GIT_CLONE="${GIT} clone"

## [1.2.0]

### Added

- `fips-*` openssl_type, which uses fips-provider, by changing:
  - `${OPENSSL}` to `./util/wrap.pl -fips ${OPENSSL}` (except for Mingw-w64)
  - `${PLOT_SCRIPT}` to `${ARR_PLOT_SCRIPT[@]}`
  - `${SPEED_OPT}` to `${ARR_SPEED_OPT[@]}`
  - The data source for RSA from `rsa.log` to `rsa.dat` and `rsa_enc.dat` (to deal with `RSA encrypt setup failure.  No RSA encrypt will be done.`).

### Changed

- `dh_all.dat` from `ecdh.dat` and `ffdh.dat`.
- `dsa_all.dat` from `ecdsa.dat`, `eddsa.dat`and `dsa.dat`.

### Fixed

- Misbehavior after `*-oqsprovider*` `openssl_type` by unsetting
  its variables.

## [1.1.0]

### Added

- A solution to `ModuleNotFoundError` in README.
- PQCs in the default provider for OpenSSL 3.5.0 and newer in
  `pqc_{kem,sig}_def.{log,dat}` and so on, though there still exist
  the following issues:
  - `openssl speed` for `ML-DSA-{44,65,87}` and
    `SLH-DSA-SHA{2,KE}-{128,192,256}{s,f}` still causes
    [this error](https://github.com/openssl/openssl/issues/27108) at least up to OpenSSL 3.6.0-dev.
  - PQCs in the oqsprovider are available only with oqsprover newer than
    0.8.0 (at least `ff34add`).
  - ML-KEM in the default provider is slower than mlkem in the oqsprovider.

### Changed

- 'oqs' of `oqs_{kem,sig}_sel.{log,dat}` to 'pqc' and moved the processes for `pqc_{kem,sig}_sel.{log,dat}` outside of 'if [ -n "${LIBOQS_VER}" ];' to include PQCs in both the default and oqs providers.

### Fixed

- Errors of `plot_openssl_speed_all.sh <openssl_tag>-minwg` (caused after the support of oqsprovider).
- Errors of `plot_openssl_speed.sh -p` option for `plot_openssl_speed_all.sh`
  for the openssl command in the PATH.

## [1.0.1]

### Added

- Keccak-derived algorithms to [keccak_128bs.png](./figs/keccak_128bs.png) and [keccak_256bs.png](./figs/keccak_256bs.png).
- SHAKE to [hash.png](./figs/hash.png).
- KMAC to [hmac.png](./figs/hmac.png).

### Removed

- Algorithm selection using versions and project names in plot_openssl_speed_all.sh since unknown algorithms are ignored in plot_openssl_speed.sh.

## [1.0.0]

### Added

- [Open Quantum Safe (OQS) project](https://openquantumsafe.org/)'s quantum-safe cryptographic algorithms available in the combination of OpenSSL 3, [oqs-provider](https://github.com/open-quantum-safe/oqs-provider/) and [liboqs](https://github.com/open-quantum-safe/liboqs).
- `openssl speed rsa` 9-column format for openssl-3.x.x.
- [Flowcharts](./README-flowchart.md)
- [with_webdata.sh](./data_from_web/with_webdata.sh) to plot with web data on [Post-Quantum signatures zoo](https://pqshield.github.io/nist-sigs-zoo/#performance) and [eBATS: ECRYPT Benchmarking of Asymmetric Systems](https://bench.cr.yp.to/ebats.html).
- [utils](./utils) dir including:
  - [common.sh](./utils/common.sh) as a common script.
  - [plot_fit.sh](./utils/plot_fit.sh) moved from `../`.
  - [set_oqsprovider.sh](./utils/set_oqsprovider.sh) against "speed: Unknown algorithm \<oqs algorithm\>" error.

### Changed

- Made `*.sh` 'set -e' compatible.
- In [plot_openssl_speed_all.sh](./plot_openssl_speed_all.sh):
  - Introduced `openssl_type` and `oqsprovider_type` for the argument.
  - `${openssl_in_path_dir}` to `default_${OPENSSL_VER_NOSPACE}` from `default_openssl_${openssl_ver_num_only}` to cover forked openssl projects such as LibreSSL.
  - `sig256.png` to `sig_128bs.png` where `bs` stands for (classical) `bit security`.
- In [plot_openssl_speed.sh](./plot_openssl_speed.sh):
  - Unified TABLE_TYPE's of asymmetric key cryptographies to either`sig_ver_keygen` or `dec_enc_keygen_dh` for signatures and encryption algorithms, respectively.
  - `measure()` sets global TABLE_TYPE or table_type() sets it.
  - Option `-d data_file_to_graph` with no `-o filename.png` gives `filename.png` automatically from `data_file_to_graph`.

<!--
- Option to use existing \*.dat.
- To accept multiple spaces and head spaces. -->

## [0.0.0]

- Initial version.

<!--
## Template
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
-->
