# [
EXTREMEKRNL_REPO="https://github.com/samsunggithub/test/releases"

REPLACE_KERNEL_BINARIES()
{
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    # 
    ZIP_LINK="$EXTREMEKRNL_REPO/latest/download/ExtremeKRNL-Quant-v2-N10-${TARGET_CODENAME}.zip"
    
    LOG "Downloading $(basename "$ZIP_LINK")"
    curl -L -s -o "$TMP_DIR/krnl.zip" "$ZIP_LINK"

    LOG "Extracting kernel binaries"
    echo $WORK_DIR
    rm -f "$WORK_DIR/kernel/"*.img
    unzip -q -j "$TMP_DIR/krnl.zip" \
        "files/boot.img" "files/dtbo.img" "files/dtb.img" \
        -d "$WORK_DIR/kernel"

    rm -rf "$TMP_DIR"
}

REPLACE_KERNEL_BINARIES