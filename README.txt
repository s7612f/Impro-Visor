Impro-Visor (Improvisation Advisor)
==================================

Impro-Visor helps musicians practice improvisation by generating stylistically
coherent chord progressions, solos, and backing tracks. The project stalled for
several years, so this repository is focused on rebuilding turnkey installers
for modern macOS and Linux systems while refreshing the developer
documentation.

Project status
--------------
* **Source code:** actively maintained in this Git repository.
* **Binary releases:** retooling in progress. Use the packaging scripts below
to build platform images until new official downloads are published.

Prerequisites
-------------
The build and packaging steps rely on:

* Java Development Kit (JDK) 21 or newer with the `jpackage` tool available on
your `PATH`.
* [Apache Ant](https://ant.apache.org/) 1.10 or newer.
* A shell environment with common Unix utilities (`bash`, `tar`, `find`, and
  `cp`).

Building the base distribution
------------------------------
Run the standard Ant build to produce a platform-neutral distribution image:

```
ant dist
```

Ant writes the application JAR and its bundled data files to the directory
named by the `distDir` property (currently `improvisor1020`). You can launch
Impro-Visor directly from this folder on any platform:

```
java -jar improvisor1020/improvisor.jar
```

macOS: creating a signed-ready DMG
----------------------------------
Use the helper script to wrap the distribution in a self-contained DMG with an
embedded Java runtime:

```
./packaging/macos/build_dmg.sh
```

The script will:

1. Run `ant dist` (and `ant clean` first, unless `--skip-clean` is supplied).
2. Detect the Ant distribution directory or use a custom value passed via
   `--dist-dir`.
3. Stage the application resources for `jpackage` and generate
   `build/distributions/Impro-Visor-<version>-macOS-<arch>.dmg`.

Additional flags include `--app-version <version>` to override the version
string and `--dest <path>` to choose a different output directory.

Linux: building a portable runtime
----------------------------------
Use the companion script to create a Linux application image backed by the
current JDK:

```
./packaging/linux/build_app_image.sh
```

By default the script builds a relocatable tarball at
`build/distributions/Impro-Visor-<version>-linux-<arch>.tar.gz`. Pass
`--type deb` or `--type rpm` to have `jpackage` assemble native packages
instead. The same `--app-version`, `--dest`, `--dist-dir`, and `--skip-clean`
flags available on macOS are supported here as well.

Continuous integration
----------------------
Two GitHub Actions workflows automate the packaging scripts:

* **Build macOS DMG** (`.github/workflows/macos-dmg.yml`) runs on the latest
  Intel and Apple Silicon macOS runners and uploads DMG artifacts.
* **Build Linux package** (`.github/workflows/linux-package.yml`) runs on
  Ubuntu and publishes the generated tarball (or native package if requested).

Issue tracking and community
----------------------------
Report bugs or feature requests through the
[GitHub issue tracker](https://github.com/Impro-Visor/Impro-Visor/issues).
Feel free to open pull requests for improvements or packaging adjustments.

The Impro-Visor project was created by Prof. Robert Keller at Harvey Mudd
College and has benefited from contributions by many students and community
members since 2005. Thank you for helping bring it back to life!
