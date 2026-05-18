# HEIC to JPG Converter

A small bash script for converting `.heic` and `.heif` images to JPEG with ImageMagick.

This script is designed for quick photo cleanup jobs: point it at a folder, optionally recurse through subfolders, choose an output directory, decide how existing files should be handled, and delete originals only after successful conversion.

## Features

- Converts `.heic`, `.HEIC`, `.heif`, and `.HEIF` files.
- Supports single-folder or recursive conversion.
- Writes JPGs beside the originals or mirrors the folder structure into an output directory.
- Handles existing output files with `skip`, `overwrite`, or `rename`.
- Optional JPEG quality, percentage scaling, advanced resize geometry, metadata stripping, and timestamp preservation.
- Dry-run mode for checking exactly what will happen.
- Safe original deletion: only successful conversions are eligible, and deletion requires confirmation unless `--yes` is used.
- Works with spaces and special characters in file names.

## Requirements

Install ImageMagick with HEIC support.

```bash
brew install imagemagick
```

Verify that ImageMagick is available:

```bash
magick -version
```

## Usage

```bash
./heic_to_jpg.sh [options]
```

Convert HEIC/HEIF files in the current folder:

```bash
./heic_to_jpg.sh
```

Convert a folder recursively into a separate JPEG folder:

```bash
./heic_to_jpg.sh --input ~/Pictures/imports --output ~/Pictures/jpeg --recursive
```

Preview a recursive conversion without writing files:

```bash
./heic_to_jpg.sh --input ~/Pictures/imports --recursive --dry-run
```

Reduce image dimensions to 50%:

```bash
./heic_to_jpg.sh --scale 50
```

Enlarge image dimensions to 125%:

```bash
./heic_to_jpg.sh --scale 125
```

Create smaller sharing copies and remove metadata:

```bash
./heic_to_jpg.sh --quality 85 --scale 50 --strip
```

Use advanced ImageMagick resize geometry:

```bash
./heic_to_jpg.sh --resize '2048x2048>'
```

Delete originals after successful conversion:

```bash
./heic_to_jpg.sh --delete-originals
```

Use non-interactive deletion for automation:

```bash
./heic_to_jpg.sh --delete-originals --yes
```

## Options

| Option | Description |
| --- | --- |
| `-i, --input DIR` | Directory containing HEIC/HEIF files. Defaults to the current directory. |
| `-o, --output DIR` | Directory for JPEGs. Defaults to beside each source file. |
| `-r, --recursive` | Include subdirectories. With `--output`, folder structure is preserved. |
| `-q, --quality N` | JPEG quality from `1` to `100`. Default: `92`. |
| `--scale PERCENT` | Scale image dimensions by percentage. Use values below `100` to reduce and above `100` to enlarge, such as `50`, `125`, or `12.5%`. |
| `--resize GEOMETRY` | Resize using ImageMagick geometry, such as `2048x2048>`, `50%`, or `1600x`. Cannot be combined with `--scale`. |
| `--strip` | Remove metadata from output files. |
| `--keep-dates` | Copy the source file modification date to the converted JPEG. |
| `--extension EXT` | Output extension: `jpg` or `jpeg`. Default: `jpg`. |
| `--conflict MODE` | Existing-file behavior: `skip`, `overwrite`, or `rename`. Default: `skip`. |
| `--delete-originals` | Prompt to remove originals after successful conversion. |
| `-y, --yes` | Answer yes to prompts. |
| `-n, --dry-run` | Show planned work without converting or deleting. |
| `-v, --verbose` | Print each conversion as it runs. |
| `-h, --help` | Show help. |
| `--version` | Show the script version. |

## Notes

The script uses ImageMagick's `magick` command instead of `mogrify` so each output path can be chosen deliberately. That makes dry runs, mirrored output folders, collision handling, percentage scaling, and safe deletion easier to reason about.

## Testing

Run the smoke test:

```bash
./tests/smoke.sh
```

The test creates temporary image fixtures, runs dry-run and real recursive conversions, verifies mirrored output paths, and confirms that the result is a JPEG.
