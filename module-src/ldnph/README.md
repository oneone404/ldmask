# LDNPH release dependency

User-supplied archive: `LDNPH.zip`, 502,389 bytes.

- SHA256: `7958565e9d3fc17b0fcf39f9899a4e6b298b51ed3c1c63858cbbbe0c09d376a1`.
- Original module ID: `zygisk_il2cppdumper`.
- Original module name/version: `Il2CppDumper`, `v1.2.0`, versionCode `1`.
- Original metadata author: `Perfare`; this metadata alone does not authenticate provenance.
- Four Zygisk ELF libraries: ARM32, ARM64, x86 and x86_64. This is not a root-hiding module.
- No source supplied. Binary behavior has not been audited and this change does not install or execute the libraries on any LD.
- Quick Install display name is LDNPH. Do not rewrite module.prop or binary identity just to change the display name.
- Package the exact user archive using `tools/package-modules.ps1 -LDNphZip <path>`. The packager pins its SHA256 and copies it byte-for-byte. The release asset supplies the binary dependency; no claim of recovered source.
- Publication flag: `catalog.json` -> `optionalModules` -> `zygisk_il2cppdumper` -> `published`.
- A false publication flag hides Quick Install selection; it is not access control for already-public release URLs or downloaded copies.
