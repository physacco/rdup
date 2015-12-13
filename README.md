# RDup

This program finds duplicate files in multiple directories and interactively remove any of them as you wish.

It is inspired by [fdupes](https://github.com/adrianlopezroche/fdupes) and [fastdupes](https://github.com/ssokolow/fastdupes).

Written in pure Ruby. No external dependencies. Cross-platform.

Tested on Ruby 2.2.2, but it should be able to run on Ruby >= 2.0.

## Algorithm

Files with the same SHA1 digests are considered as duplicates.

RDup implements the Duplicates Finding Algorithm used by fastdupes:

1. The given paths are recursively walked to gather a list of files.
2. Files are grouped by size and single-entry groups are pruned away.
3. Groups are subdivided and pruned by hashing the first *16KiB* of each file.
4. Groups are subdivided and pruned again by hashing full contents.
5. Any groups which remain are sets of duplicates.

By using this algorithm, RDup performs much faster than fdupes.

## Installation

`gem install rdup`

## Usage

```
Usage: rdup [options] dir1 [dir2 ...]

Options:
  -h, --help                Print this help message and exit
  -v, --version             Print version information and exit
  -t, --mtime               Show each file's mtime
  -d, --delete              Delete duplicated files (with prompt)
  -n, --dry-run             Don't actually delete any files
  --min-size=NUM            Files below this size will be ignored
```

## Example

```
$ rdup --mtime --delete --dry-run foo/ bar/
Found 5 files to be compared for duplication.
Found 2 sets of files with identical sizes. (5 files in total)
Found 2 sets of files with identical header hashes. (5 files in total)
Found 2 sets of files with identical hashes. (5 files in total)

[1/2] SHA1: c56351f9f9eb825c743141dd4acc870166838e3c, Size: 880 bytes
  1) 2015-12-13 17:07:52 +0800  foo/abc/abc.dat
  2) 2015-12-13 17:08:04 +0800  bar/abc.dat
Which to preserve (1,2 or all): 1
  [+] foo/abc/abc.dat
  [-] bar/abc.dat

[2/2] SHA1: 500fe2c2d2018bbe97a1341cf826335aaafab3d9, Size: 1,076 bytes
  1) 2015-12-13 17:07:13 +0800  foo/abc/foo.txt
  2) 2015-12-13 17:06:49 +0800  foo/foo.txt
  3) 2015-12-13 17:07:25 +0800  bar/bar.txt
Which to preserve (1,2,3 or all): 2
  [-] foo/abc/foo.txt
  [+] foo/foo.txt
  [-] bar/bar.txt
```

## Known issues

* RDup doesn't follow Windows [Shortcut files](https://en.wikipedia.org/wiki/File_shortcut). Shortcuts are treated as normal files.

