source ./lib.sh

scan_directory() {
local dir="$1"
local files=0
local folders=0

for item in "$dir"/*; do
  if [ -d "$item" ]; then
   echo "[dir ] $(basename "$item")"
   folders=$((folders + 1))
  elif [ -f "$item" ]; then
   echo "[file] $(basename "$item")"
   files=$((files + 1))
  fi
done

echo "Files: $files Folders: $folders"
log_action "scan: $dir ($files files, $folders folders)"
}

permission_audit() {
local dir="$1"
local unreadable=0
local executable=0

for item in "$dir"/*; do
  if [ -f "$item" ]; then
     local perms=""


     if [ -r "$item" ]; then perms="${perms}r"; else perms="${perms}-"; fi
     if [ -w "$item" ]; then perms="${perms}w"; else perms="${perms}-"; fi
     if [ -x "$item" ]; then perms="${perms}x"; else perms="${perms}-"; fi
     echo "$perms $(basename "$item")"
     if [ ! -r "$item" ]; then
         unreadable=$((unreadable + 1))
     fi
     if [ -x "$item" ]; then
         executable=$((executable + 1))
     fi
  fi
done
echo "Unreadable files: $unreadable Executable files: $executable"
log_action "perms: $dir ($unreadable unreadable, $executable executable)"

}

extension_report() {
local dir="$1"
declare -A counts
local ext

for item in "$dir"/*; do
    if [ -f "$item" ]; then
        local name
        name=$(basename "$item")
        ext="${name##*.}"
        case "$ext" in
            txt|log|sh|jpg) ;;
            *) ext="other" ;;
        esac


        counts[$ext]=$((${counts[$ext]:-0} + 1 ))
    fi
done
for key in "${!counts[@]}"; do
  echo "$key : ${counts[$key]}"
done

log_action "ext: $dir"
}

search_file() {
local dir="$1"
local pattern
local found=0
read -p "Enter text to search for :" pattern
for item in "$dir"/*; do
   if [ -f "$item" ]; then
      local name
      name=$(basename "$item")
      if [[ "$name" == *"$pattern"* ]]; then
          echo "$name"
          found=$((found + 1))
      fi
   fi
done
if [ "$found" -eq 0 ]; then
   echo "No file matches '$pattern'."
fi

log_action "search: '$pattern' in $dir ($found found)"
}

backup_all() {
local dir="$1"
local folder="backups"
local saved=0
local skipped=0
mkdir -p "$folder"
for item in "$dir"/*; do
  if [ -f "$item" ]; then
     local name
     name=$(basename "$item")
     if [ -r "$item" ]; then
         local stamp
         stamp=$(date +%Y%m%d_%H%M%S)
         cp "$item" "$folder/${name}_${stamp}.bak"
         saved=$((saved + 1))
     else
         log_error "Cannot read '$name', skipped."
         skipped=$((skipped + 1))
     fi
  fi
done

echo "Saved: $saved skipped: $skipped"
log_action "backup: $dir ($saved saved, $skipped skipped)"
}

list_backups() {
local folder="backups"
local count=0
for item in "$folder"/*.bak; do
  if [ -f "$item" ]; then
     basename "$item"
     count=$((count + 1))
  fi
done
if [ "$count" -eq 0 ]; then
    echo "(no backups yet)"
fi
log_action "list_backups: $count found"
}

restore_backup() {
local dir="$1"
local folder="backups"
local name
read -p "Enter backups name to restore : " name 
if [ ! -f "$folder/$name" ]; then
  log_error "backup '$name' does not exist."
  return 1
fi
cp -n "$folder/$name" "$dir/restored_$name"
log_info "Restore as: $dir/restored_$name"
log_action "restore: $name -> $dir/restored_$name"
return 0
}

show_menu() {
local dir="$1"
local choice

while true; do
   echo
   echo "===File Auditor & Backup tool==="
   echo "1- Scan Directory"
   echo "2- permission audit"
   echo "3- Extension report"
   echo "4- search all"
   echo "5- Backup all"
   echo "6- List backups"
   echo "7- Restore backup"
   echo "8- exit"
   read -p "Choose an option [1-8]: " choice

   case "$choice" in
      1) scan_directory "$dir" ;;
      2) permission_audit "$dir" ;;
      3) extension_report "$dir" ;;
      4) search_file "$dir" ;;
      5) backup_all "$dir" ;;
      6) list_backups ;;
      7) restore_backup "$dir" ;;
      8) echo "Goodbye."; break ;;
      *) log_error "Invalid choice, try again"

   esac
done
}

dir="${1:-.}"
action="$2"
require_dir "$dir"
case "$action" in 
   scan)  scan_directory "$dir" ;;
   perms) permission_audit "$dir" ;;
   ext)   extension_report "$dir" ;;
   backup)backup_all "$dir" ;;
   "")    show_menu "$dir" ;;
   *)     log_error "unknown action '$action' (use: scan | perms | ext | backup)"; exit 1 ;;
esac

