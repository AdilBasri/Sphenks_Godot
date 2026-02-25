import os
import shutil
import re
from pathlib import Path

# Godot project root
PROJECT_ROOT = Path("C:/Users/hp/Documents/sphenks")

# New target directories
DIRECTORIES = {
    "Scripts": PROJECT_ROOT / "Scripts",
    "Scenes": PROJECT_ROOT / "Scenes",
    "Scenes/Enemies": PROJECT_ROOT / "Scenes/Enemies",
    "Scenes/Items": PROJECT_ROOT / "Scenes/Items",
    "UI": PROJECT_ROOT / "UI",
    "Materials_Shaders": PROJECT_ROOT / "Materials_Shaders",
    "Assets/Images": PROJECT_ROOT / "Assets/Images",
    "Assets/Fonts": PROJECT_ROOT / "Assets/Fonts"
}

# Mapping of file name to its new directory path relative to project root
FILE_MAPPINGS = {}

def create_directories():
    for name, path in DIRECTORIES.items():
        path.mkdir(parents=True, exist_ok=True)
        print(f"Ensured directory exists: {path}")

def classify_file(filepath: Path) -> str:
    filename = filepath.name
    ext = filepath.suffix.lower()
    
    # Ignore already organized folders and godot system folders
    if filepath.parent != PROJECT_ROOT:
        return None
        
    ignored_names = [".godot", ".git", "project.godot", ".gitignore", ".gitattributes", ".editorconfig", "icon.svg", "icon.svg.import"]
    if filename in ignored_names:
        return None
        
    # Scripts
    if ext == ".gd":
        if "UI" in filename or "menu" in filename.lower() or "arayuz" in filename.lower():
            return "UI"
        return "Scripts"
        
    # Scenes
    if ext == ".tscn":
        lower_name = filename.lower()
        if "menu" in lower_name or "arayuz" in lower_name or "ui" in lower_name:
            return "UI"
        if "dusman" in lower_name or "canavar" in lower_name or "boss" in lower_name:
            return "Scenes/Enemies"
        if "mermi" in lower_name or "altin" in lower_name or "kapi" in lower_name or "market" in lower_name or "nesne" in lower_name or "item" in lower_name or "bilet" in lower_name:
            return "Scenes/Items"
        return "Scenes"
        
    # Materials & Shaders
    if ext in [".tres", ".gdshader"]:
        return "Materials_Shaders"
        
    # Images (root only)
    if ext in [".png", ".jpg", ".jpeg"]:
        return "Assets/Images"
        
    # Fonts
    if ext in [".ttf", ".otf"]:
        return "Assets/Fonts"
        
    return None

def build_move_plan():
    for item in PROJECT_ROOT.iterdir():
        if item.is_file():
            target_dir = classify_file(item)
            if target_dir:
                old_rel = item.name
                new_rel = f"{target_dir}/{item.name}"
                FILE_MAPPINGS[old_rel] = new_rel
                
                # Also handle associated .import files for resources
                import_file = item.with_name(item.name + ".import")
                if import_file.exists():
                    FILE_MAPPINGS[import_file.name] = f"{target_dir}/{import_file.name}"
                
                # Also handle associated .uid files for scripts/resources
                uid_file = item.with_name(item.name + ".uid")
                if uid_file.exists():
                    FILE_MAPPINGS[uid_file.name] = f"{target_dir}/{uid_file.name}"

def move_files():
    print(f"\nMoving {len(FILE_MAPPINGS)} files...")
    for old_rel, new_rel in FILE_MAPPINGS.items():
        old_path = PROJECT_ROOT / old_rel
        new_path = PROJECT_ROOT / new_rel
        
        if old_path.exists():
            shutil.move(str(old_path), str(new_path))
            print(f"Moved: {old_rel} -> {new_rel}")

def update_references():
    print("\nUpdating references...")
    # Extensions that might contain resource paths
    extensions_to_check = [".tscn", ".gd", ".tres", ".godot"]
    
    # Find all files to check (including previously moved ones or untouched ones in subdirs)
    files_to_check = []
    for root, _, files in os.walk(PROJECT_ROOT):
        if ".git" in root or ".godot" in root:
            continue
        for file in files:
            if any(file.endswith(ext) for ext in extensions_to_check):
                files_to_check.append(Path(root) / file)
                
    # Prepare exact regex replacements to prevent partial matches
    replacements = []
    for old_rel, new_rel in FILE_MAPPINGS.items():
        # don't replace .import or .uid strings directly inside res:// paths usually
        if old_rel.endswith(".import") or old_rel.endswith(".uid"):
            continue
            
        old_res = f"res://{old_rel}"
        new_res = f"res://{new_rel}"
        
        # Exact match replacement
        replacements.append((old_res, new_res))

    # Apply to config files and code
    for filepath in files_to_check:
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
                
            original_content = content
            for old_res, new_res in replacements:
                content = content.replace(old_res, new_res)
                
            if content != original_content:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Updated references in: {filepath.relative_to(PROJECT_ROOT)}")
        except Exception as e:
            print(f"Failed to read/write {filepath.name}: {e}")

def main():
    print("Starting Sphenks Project Reorganization...")
    create_directories()
    build_move_plan()
    
    if not FILE_MAPPINGS:
        print("No files to move!")
        return
        
    print(f"Found {len(FILE_MAPPINGS)} files to organize.")
    move_files()
    update_references()
    print("Reorganization Complete!")

if __name__ == "__main__":
    main()
