# Change Log

All notable changes, such as backward incompatibilities, will be documented in this file.

<!-- markdownlint-disable MD024 no-duplicate-heading -->

<!-- ## [Unreleased 1.0.2] -->

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
