#!/usr/bin/env bash
# Deploys `# @nemo` or `# @kde` scripts to Dolphin/KDE service menus
# Creates .desktop files in ~/.local/share/kservices5/ServiceMenus/

# Default source directory - can be overridden with SOURCE_DIR environment variable
SOURCE_DIR="${SOURCE_DIR:-$HOME/scripts}"
TARGET_BASE="$HOME/.local/share/kservices5/ServiceMenus"

# Validate source directory
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "❌ Error: Source directory not found: $SOURCE_DIR"
    echo "   Set SOURCE_DIR environment variable or ensure $HOME/scripts exists"
    exit 1
fi

echo "🧹 Cleaning target subfolders (except root)..."
find "$TARGET_BASE" -mindepth 1 -type d -exec rm -rf {} +
find "$TARGET_BASE" -maxdepth 1 -type f -name "*.desktop" -delete

mkdir -p "$TARGET_BASE"

# Scripts that must stay together in root due to interdependencies
KEEP_IN_ROOT=(
  dailies.sh
  dailies_gui.sh
  exrtomp4.sh
  exrtomp4_dailies.sh
  exrtoprores422.sh
  exrtoprores444.sh
)

# Function to determine if script works on directory vs files
script_works_on_directory() {
    local name="$1"
    # Scripts that process all files in directory (like exrtomp4.sh, dailies.sh)
    # Note: imagepack.sh works on both directories and files, handled specially
    case "$name" in
        *exrtomp4*|*exrtoprores*|*dailies*|*folder*|*project*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Function to determine service types based on script name
get_service_types() {
    local name="$1"
    
    # Special case: date.sh should appear when clicking on empty space (all/allfiles)
    if [[ "$name" == *date* ]]; then
        echo "all/allfiles"
        return
    fi
    
    # Special case: imagepack works on both files and directories
    if [[ "$name" == *imagepack* ]]; then
        echo "inode/directory,image/x-exr"
        return
    fi
    
    # Directory-based scripts
    if script_works_on_directory "$name"; then
        case "$name" in
            *folder*|*project*)
                echo "inode/directory" ;;
            *exr*|*dailies*)
                # EXR scripts work on directories containing EXR files
                # Use directory + file pattern for .exr files
                echo "inode/directory" ;;
            *)
                # Directory-based but also work on files in that directory
                echo "inode/directory" ;;
        esac
    else
        # File-based scripts - use specific MIME types
        case "$name" in
            # EXR-specific scripts - only for EXR files
            *exrtojpg*|*exrtopng*|*exrtotiff*|*exrmerge*|*exrarchive*)
                echo "image/x-exr" ;;
            
            # Video conversion scripts - only for video files
            *mp4*|*mkv*|*mov*|*prores*|*webmp4*|*joinvideo*|*applyaudio*|*aratio*|*videomerge*|*noaudio*|*blackframes*|*vid_cut*|*bake_audio*)
                echo "video/*" ;;
            
            # Video to image conversion
            *videotojpg*|*videotopng*|*mp4topng*)
                echo "video/*" ;;
            
            # PDF conversion scripts - only for PDF files
            *pdftojpg*)
                echo "application/pdf" ;;

            # Image conversion scripts - only for image files
            *tojpg*|*webp*|*montage*|*extract*|*thumbnail*|*gif*|*hdri*|*pano*)
                echo "image/*" ;;
            
            # PNG to MP4 (image sequence to video)
            *pngtomp4*)
                echo "image/png" ;;
            
            # Generic image processing
            *image*|*merge*|*archive*)
                echo "image/*" ;;
            
            # Default: show for all files
            *)
                echo "all/allfiles" ;;
        esac
    fi
}

# Function to determine target folder
get_target_folder() {
    local name="$1"
    if [[ " ${KEEP_IN_ROOT[*]} " == *" $name "* ]]; then
        echo "$TARGET_BASE"
    else
        case "$name" in
            *applyaudio*|*mp4*|*webmp4*|*joinvideo*|*mkv*|*prores*|*aratio*|*exrtomp4*|*exrtoprores*|*blackframes*|*vid_cut*|*bake_audio*)
                echo "$TARGET_BASE/video" ;;
            *exrtojpg*|*exrtotiff*|*exrtopng*|*merge*|*extract*|*archive*|*montage*|*image*|*webp*|*tojpg*|*pdftojpg*|*hdri*|*pano*)
                echo "$TARGET_BASE/image" ;;
            *project*|*folder*|*date*)
                echo "$TARGET_BASE/project" ;;
            *)
                echo "$TARGET_BASE/misc" ;;
        esac
    fi
}

# Function to get MimeType patterns for file extension matching
get_mime_type_patterns() {
    local name="$1"
    local service_types="$2"
    
    # Skip MimeType for directory-based scripts and all/allfiles (empty space clicks)
    if [[ "$service_types" == "inode/directory" ]] || [[ "$service_types" == "all/allfiles" ]]; then
        return
    fi
    
    # Add specific MIME type patterns for better file type matching
    case "$name" in
        # EXR-specific scripts
        *exrtojpg*|*exrtopng*|*exrtotiff*|*exrmerge*|*exrarchive*)
            echo "MimeType=image/x-exr;"
            ;;
        # Video formats
        *mp4*|*webmp4*)
            echo "MimeType=video/mp4;"
            ;;
        *mkv*)
            echo "MimeType=video/x-matroska;"
            ;;
        *mov*|*prores*)
            echo "MimeType=video/quicktime;"
            ;;
        # PDF format
        *pdf*)
            echo "MimeType=application/pdf;"
            ;;
        # Image formats
        *tojpg*|*jpg*)
            echo "MimeType=image/jpeg;"
            ;;
        *png*|*pngtomp4*)
            echo "MimeType=image/png;"
            ;;
        *tiff*)
            echo "MimeType=image/tiff;"
            ;;
        *webp*)
            echo "MimeType=image/webp;"
            ;;
    esac
}

# Function to create .desktop file for a script
create_desktop_file() {
    local script_path="$1"
    local script_name="$2"
    local target_dir="$3"
    local service_types="$4"
    
    local display_name="${script_name%.sh}"
    # display_name=$(echo "$display_name" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
    # Use the script name as is (without .sh) to avoid spaces

    
    # Create unique action name based on script name (sanitized for desktop file)
    local action_name=$(echo "$script_name" | sed 's/[^a-zA-Z0-9]/_/g')
    
    local desktop_file="${target_dir}/${script_name}.desktop"
    local mime_types=$(get_mime_type_patterns "$script_name" "$service_types")
    
    # Determine execution pattern
    # Create a wrapper script for each action to avoid complex escaping
    local wrapper_script="${target_dir}/.wrapper_${action_name}.sh"
    
    # Special handling for date.sh - works on empty space (all/allfiles)
    if [[ "$script_name" == *date* ]] && [[ "$service_types" == *all/allfiles* ]]; then
        # date.sh creates a date folder in current directory when clicking empty space
        cat > "$wrapper_script" <<WRAPPER_EOF
#!/bin/bash
# date.sh works when clicking on empty space - use current directory
# %U might be empty or point to the directory, get the directory path
if [ $# -gt 0 ] && [ -n "\$1" ] && [ "\$1" != "" ]; then
    TARGET="\$1"
    TARGET="\${TARGET#file://}"
    TARGET="\${TARGET//%20/ }"
    if [ -d "\$TARGET" ]; then
        cd "\$TARGET" && "$script_path" >/dev/null 2>&1 &
    else
        # If not a directory, try to get parent directory
        DIR="\$(dirname "\$TARGET")"
        if [ -d "\$DIR" ] && [ "\$DIR" != "." ]; then
            cd "\$DIR" && "$script_path" >/dev/null 2>&1 &
        else
            # Fallback: use current directory (empty space click)
            "$script_path" >/dev/null 2>&1 &
        fi
    fi
else
    # No argument or empty - empty space click, use current directory
    "$script_path" >/dev/null 2>&1 &
fi
WRAPPER_EOF
        exec_line="bash \"$wrapper_script\" \"%U\""
    # Special handling for imagepack.sh which works on both files and directories
    elif [[ "$script_name" == *imagepack* ]]; then
        cat > "$wrapper_script" <<WRAPPER_EOF
#!/bin/bash
FILES=()
for url in "\$@"; do
    path="\$url"
    path="\${path#file://}"
    path="\${path//%20/ }"
    if [ -f "\$path" ]; then
        FILES+=("\$path")
    elif [ -d "\$path" ]; then
        # If it's a directory, cd to it and run without arguments (processes all EXR in dir)
        cd "\$path" && "$script_path" >/dev/null 2>&1 &
        exit 0
    fi
done
if [ \${#FILES[@]} -gt 0 ]; then
    # Process selected files
    "$script_path" "\${FILES[@]}" >/dev/null 2>&1 &
else
    notify-send "Error" "No valid files or directories selected" 2>/dev/null || true
fi
WRAPPER_EOF
        exec_line="bash \"$wrapper_script\" %U"
    elif script_works_on_directory "$script_name"; then
        # Scripts that work on directories
        # Special handling for date.sh - works on empty space (all/allfiles)
        if [[ "$script_name" == *date* ]] && [[ "$service_types" == "all/allfiles" ]]; then
            # date.sh creates a date folder in current directory when clicking empty space
            cat > "$wrapper_script" <<WRAPPER_EOF
#!/bin/bash
# date.sh works when clicking on empty space - use current directory
# %U might be empty or point to the directory, get the directory path
if [ -n "\$1" ] && [ "\$1" != "" ]; then
    TARGET="\$1"
    TARGET="\${TARGET#file://}"
    TARGET="\${TARGET//%20/ }"
    if [ -d "\$TARGET" ]; then
        cd "\$TARGET" && "$script_path" >/dev/null 2>&1 &
    else
        # If not a directory, try to get parent directory
        DIR="\$(dirname "\$TARGET")"
        if [ -d "\$DIR" ] && [ "\$DIR" != "." ]; then
            cd "\$DIR" && "$script_path" >/dev/null 2>&1 &
        else
            # Fallback: use current directory (empty space click)
            "$script_path" >/dev/null 2>&1 &
        fi
    fi
else
    # No argument or empty - empty space click, use current directory
    "$script_path" >/dev/null 2>&1 &
fi
WRAPPER_EOF
            exec_line="bash \"$wrapper_script\" \"%U\""
        elif [[ "$service_types" == "inode/directory" ]]; then
            # Check if script name suggests it takes directory argument (like dailies.sh)
            if [[ "$script_name" == *dailies* ]]; then
                # Scripts like dailies.sh accept directory as argument
                cat > "$wrapper_script" <<WRAPPER_EOF
#!/bin/bash
TARGET="\$1"
TARGET="\${TARGET#file://}"
TARGET="\${TARGET//%20/ }"
if [ -d "\$TARGET" ]; then
    "$script_path" "\$TARGET" >/dev/null 2>&1 &
else
    notify-send "Error" "Directory not found: \$TARGET" 2>/dev/null || true
fi
WRAPPER_EOF
                exec_line="bash \"$wrapper_script\" \"%U\""
            else
                # Scripts like exrtomp4.sh need to run from within the directory (no argument)
                cat > "$wrapper_script" <<WRAPPER_EOF
#!/bin/bash
TARGET="\$1"
TARGET="\${TARGET#file://}"
TARGET="\${TARGET//%20/ }"
if [ -d "\$TARGET" ]; then
    cd "\$TARGET" && "$script_path" >/dev/null 2>&1 &
else
    notify-send "Error" "Directory not found: \$TARGET" 2>/dev/null || true
fi
WRAPPER_EOF
                exec_line="bash \"$wrapper_script\" \"%U\""
            fi
        else
            # Scripts that process files in current directory
            cat > "$wrapper_script" <<WRAPPER_EOF
#!/bin/bash
TARGET="\$1"
TARGET="\${TARGET#file://}"
TARGET="\${TARGET//%20/ }"
if [ -d "\$TARGET" ]; then
    cd "\$TARGET" && "$script_path" >/dev/null 2>&1 &
else
    notify-send "Error" "Directory not found: \$TARGET" 2>/dev/null || true
fi
WRAPPER_EOF
            exec_line="bash \"$wrapper_script\" \"%U\""
        fi
    else
        # Scripts that work on selected files
        cat > "$wrapper_script" <<WRAPPER_EOF
#!/bin/bash
FILES=()
for url in "\$@"; do
    path="\$url"
    path="\${path#file://}"
    path="\${path//%20/ }"
    FILES+=("\$path")
done
if [ \${#FILES[@]} -gt 0 ]; then
    DIR="\$(dirname "\${FILES[0]}")"
    cd "\$DIR" && "$script_path" "\${FILES[@]}" >/dev/null 2>&1 &
else
    notify-send "Error" "No files selected" 2>/dev/null || true
fi
WRAPPER_EOF
        exec_line="bash \"$wrapper_script\" %U"
    fi
    
    chmod +x "$wrapper_script"
    
    # Build desktop file content
    # Use X-KDE-ServiceTypes for Dolphin compatibility
    # Include KonqPopupMenu/Plugin to make it appear in context menu
    local kde_service_types="KonqPopupMenu/Plugin"
    if [[ "$service_types" != "all/allfiles" ]]; then
        kde_service_types="$kde_service_types,$service_types"
    else
        # For all/allfiles, still include it but also add the plugin type
        kde_service_types="$kde_service_types,all/allfiles"
    fi
    
    # Build desktop file content
    # Use unique action name per script so each appears as separate menu item
    local desktop_content="[Desktop Entry]
Type=Service
X-KDE-ServiceTypes=$kde_service_types
X-KDE-Priority=TopLevel
Actions=${action_name};
Icon=utilities-terminal"
    
    # Add MimeType if specified
    # For all/allfiles, we need MimeType=all/all; to show on empty space clicks
    if [[ "$service_types" == "all/allfiles" ]]; then
        desktop_content="$desktop_content
MimeType=all/all;"
    elif [[ -n "$mime_types" ]]; then
        desktop_content="$desktop_content
$mime_types"
    fi
    
    desktop_content="$desktop_content

[Desktop Action ${action_name}]
Name=$display_name
Exec=$exec_line"
    
    echo "$desktop_content" > "$desktop_file"
    
    chmod +x "$desktop_file"
    echo "✅ $script_name → $(realpath --relative-to="$TARGET_BASE" "$target_dir")"
}

# Scripts to exclude from deployment
EXCLUDE_SCRIPTS=(
    deploy_dolphin.sh
    folder.sh
)

# Loop over all .sh files tagged with # @nemo or # @kde
find "$SOURCE_DIR" -type f -name "*.sh" | while read -r script; do
    name=$(basename "$script")
    
    # Skip excluded scripts
    if [[ " ${EXCLUDE_SCRIPTS[*]} " == *" $name "* ]]; then
        continue
    fi
    
    # Check for @nemo or @kde tag in first 10 lines
    if head -n 10 "$script" | grep -qE '# @(nemo|kde)'; then
        target_dir=$(get_target_folder "$name")
        service_types=$(get_service_types "$name")
        
        mkdir -p "$target_dir"
        
        # Copy script to target location
        script_copy="${target_dir}/${name}"
        cp "$script" "$script_copy"
        chmod +x "$script_copy"

        # Copy associated config files (e.g., script_name_config.env or just .env)
        # Check for ${name%.sh}_config.env
        config_file="${script%.sh}_config.env"
        if [ -f "$config_file" ]; then
            cp "$config_file" "${target_dir}/"
            echo "   (Copied config: $(basename "$config_file"))"
        fi
        
        # Create .desktop file
        create_desktop_file "$script_copy" "$name" "$target_dir" "$service_types"
    fi
done

echo "🎉 Deployment complete."
echo ""
echo "🔄 Refreshing Dolphin cache..."
kbuildsycoca5 --noincremental 2>/dev/null || echo "⚠️  Warning: Could not refresh cache (kbuildsycoca5 not found)"
echo ""
echo "🔄 Restarting Dolphin..."

# Function to close Dolphin gracefully
close_dolphin() {
    # Check if Dolphin is running
    if ! pgrep -x dolphin >/dev/null 2>&1; then
        return 0
    fi
    
    # Try to close Dolphin windows using D-Bus (graceful shutdown)
    if command -v qdbus &>/dev/null; then
        # Find all Dolphin D-Bus services and close them
        for service in $(qdbus --session 2>/dev/null | grep -i dolphin || true); do
            qdbus "$service" /MainApplication quit 2>/dev/null || true
        done
    elif command -v dbus-send &>/dev/null; then
        # Alternative D-Bus method - try common service names
        for service in org.kde.dolphin org.kde.dolphin-*; do
            dbus-send --session --type=method_call --dest="$service" /MainApplication org.qtproject.Qt.QApplication.quit 2>/dev/null || true
        done
    fi
    
    # Wait a moment for graceful shutdown
    sleep 1
    
    # Force kill if still running
    if pgrep -x dolphin >/dev/null 2>&1; then
        killall dolphin 2>/dev/null || true
        sleep 0.5
    fi
}

# Close existing Dolphin instances
close_dolphin

# Restart Dolphin in background
if command -v dolphin &>/dev/null; then
    dolphin >/dev/null 2>&1 &
    echo "✅ Dolphin restarted"
else
    echo "⚠️  Warning: Dolphin not found in PATH"
fi

