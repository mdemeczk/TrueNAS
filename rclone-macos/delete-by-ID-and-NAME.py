mport json
import os
import subprocess
import sys

BUCKET = os.environ.get("B2_BUCKET", "your-bucket-name")
PREFIX = os.environ.get("B2_PREFIX", "ruenas/")

def run(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{p.stderr}")
    return p.stdout

def main():
    do_delete = os.environ.get("DO_DELETE", "0") == "1"
    # list-file-versions JSON-ben adja vissza a fileId-kat
    out = run(["b2", "list-file-versions", "--json", BUCKET, PREFIX])

    data = json.loads(out)
    files = data.get("files", [])
    print(f"Found {len(files)} versions under prefix '{PREFIX}' in bucket '{BUCKET}'")

    # DRY RUN
    for f in files[:10]:
        print(f"  {f.get('fileName')}  {f.get('fileId')}")
    if not do_delete:
        print("DRY RUN only. Set DO_DELETE=1 to actually delete.")
        return

    deleted = 0
    for f in files:
        file_name = f["fileName"]
        file_id = f["fileId"]
        run(["b2", "delete-file-version", file_name, file_id])
        deleted += 1
        if deleted % 100 == 0:
            print(f"Deleted {deleted}...")

    print(f"Done. Deleted {deleted} versions.")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

