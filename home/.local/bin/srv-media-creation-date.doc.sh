#!/usr/bin/env bash

search_dir=$1

#-not -newermt 1970-01-01
find "$search_dir" -type f -iregex ".*\.\(jpg\|jpeg\|png\|gif\|bmp\|mp4\|avi\|mov\|mkv\)$" -print0 | while IFS= read -r -d $'\0' file; do
    # Attempt to get a valid date from EXIF data
    DATE_FOUND=$(exiftool -d "%Y-%m-%d %H:%M:%S" -DateTimeOriginal -MediaCreateDate -CreateDate -s3 -s -s "$file" | grep -m 1 . || echo "nodate")

    # If no EXIF date, try to extract date from filename
    if [ "$DATE_FOUND" = "nodate" ] || [ "$DATE_FOUND" = "0000:00:00 00:00:00" ]; then
        DATE_FOUND="1970-01-01 00:00:00"
    fi

    touch -m -d "$DATE_FOUND" "$file"
    echo "Updated $file to $DATE_FOUND"
done
