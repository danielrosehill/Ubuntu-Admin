---
name: files-organise
description: Tidy a cluttered directory — propose a folder structure, sort loose files into type folders (documents, images, audio, video, archives…), split photos from videos, flatten nested folders without name clashes, chunk a huge folder into numbered subfolders of N files, and consolidate overlapping folders. Always shows a dry-run plan and asks before moving; never deletes without explicit approval. Use when asked "tidy my Desktop", "organise this folder", "sort these files by type", "flatten this folder", "split this folder into batches of 500", "separate photos and videos", or "merge these similar folders". Works locally or on a remote host over SSH.
---

# Organise files

Operates on the current directory (or a path the user names). Plan → confirm → move → report.

## Target

Local by default. Remote: run the same commands via `ssh <host> 'cd <dir> && …'`. Never run on `/`, `/etc`, `/usr`, `/var` or a home directory root without the user naming it explicitly.

## 1. Survey

```bash
cd <dir>
find . -maxdepth 1 -type f | wc -l; find . -maxdepth 1 -mindepth 1 -type d | wc -l
find . -maxdepth 1 -type f -printf '%f\n' | sed -n 's/.*\.\([^.]*\)$/\L\1/p' | sort | uniq -c | sort -rn | head -30
du -sh .
```

Skip `.desktop` launchers on a Desktop, hidden files, and anything the user flagged.

## 2. Type map (default)

| Folder | Extensions |
| --- | --- |
| `documents/` | pdf doc docx odt rtf txt md tex xls xlsx ods csv ppt pptx odp epub |
| `images/` | jpg jpeg png gif webp heic heif tif tiff bmp svg raw cr2 nef arw dng |
| `video/` | mp4 mkv mov avi webm m4v mts 3gp |
| `audio/` | mp3 flac wav ogg opus m4a aac wma |
| `archives/` | zip tar gz tgz xz bz2 7z rar zst |
| `installers/` | deb appimage run snap flatpakref |
| `code/` | py sh js ts json yaml yml toml ipynb |
| `other/` | everything else |

## 3. Operations

Each operation first prints the plan (dry run), then runs on approval. Use `mv -n` (never overwrite) or `--backup=numbered`.

**Sort loose files by type**

```bash
declare -A MAP=([pdf]=documents [docx]=documents [txt]=documents [md]=documents [jpg]=images [jpeg]=images [png]=images [heic]=images [mp4]=video [mkv]=video [mov]=video [mp3]=audio [flac]=audio [wav]=audio [zip]=archives [gz]=archives [deb]=installers [appimage]=installers)
DRY=1
find . -maxdepth 1 -type f ! -name '.*' ! -name '*.desktop' -print0 | while IFS= read -r -d '' f; do
  ext="${f##*.}"; ext="${ext,,}"; d="${MAP[$ext]:-other}"
  if [ "$DRY" = 1 ]; then echo "$f -> $d/"; else mkdir -p "$d" && mv -n -- "$f" "$d/"; fi
done
```

**Separate photos and videos** — the same loop restricted to the `images`/`video` rows.

**Flatten** (move every file in subfolders up to this level; clashes get a numeric suffix):

```bash
find . -mindepth 2 -type f -print0 | while IFS= read -r -d '' f; do
  echo mv --backup=numbered -- "$f" ./    # remove 'echo' after approval
done
# afterwards, remove now-empty dirs:  find . -mindepth 1 -type d -empty -delete
```

`--backup=numbered` renames clashes to `name.~1~`; offer to rename those to `name-1.ext` afterwards.

**Chunk into numbered folders of N files**

```bash
N=500; i=0
find . -maxdepth 1 -type f ! -name '.*' -print0 | sort -z | while IFS= read -r -d '' f; do
  d=$(printf '%03d' $(( i / N + 1 ))); mkdir -p "$d"; mv -n -- "$f" "$d/"; i=$((i+1))
done
```

**Consolidate overlapping folders** — list candidate pairs (similar names, same dominant file types), show a merge plan (`target ← sources`), then `rsync -a --ignore-existing src/ target/` and remove a source only when it is empty or the user approves.

**Propose a structure** — when the user wants a design first: read file names, types and dates, propose a tree (max 2–3 levels, by purpose before type, dated subfolders `YYYY` or `YYYY-MM` for media), and wait for approval before moving anything.

## 4. Duplicates and deletions

- Suspected junk (old installers, `Untitled*`, empty files, partial downloads `*.part`/`*.crdownload`) → list them and ask; never delete in bulk.
- Checksum-based duplicate detection → the `linux-system-optimisation` plugin's `find-duplicates` skill.
- Media dedupe after a flatten: offer it, don't do it automatically.

## Confirm before

- Every move/rename batch (show the dry-run first, with counts).
- Any deletion, including removing empty folders on someone else's share.

## Report

Counts moved per folder, clashes and how they were renamed, anything skipped, and the final top-level tree (`find . -maxdepth 2 -type d | sort`).

## Related

- `storage-reclaim-space` — when the goal is freeing space.
- `files-permissions` — if moves fail with permission errors.
- `linux-system-optimisation` plugin — `find-duplicates`.
