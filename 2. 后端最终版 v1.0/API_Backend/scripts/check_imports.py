
import sys
import os
import pkgutil
import importlib

# Add backend directory to sys.path
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.dirname(current_dir)
sys.path.insert(0, backend_dir)

print(f"Checking imports from: {backend_dir}")

def check_imports(start_dir):
    error_count = 0
    for root, dirs, files in os.walk(start_dir):
        if 'venv' in root or '__pycache__' in root or '.git' in root:
            continue
        
        for file in files:
            if file.endswith(".py"):
                module_path = os.path.join(root, file)
                rel_path = os.path.relpath(module_path, backend_dir)
                module_name = rel_path.replace(os.path.sep, ".")[:-3]
                
                if module_name.endswith("__init__"):
                    module_name = module_name[:-9]
                
                try:
                    importlib.import_module(module_name)
                    print(f"✅ Imported: {module_name}")
                except Exception as e:
                    print(f"❌ Failed to import {module_name}: {e}")
                    error_count += 1
    return error_count

if __name__ == "__main__":
    errors = check_imports(backend_dir)
    if errors > 0:
        print(f"\nFound {errors} import errors.")
        sys.exit(1)
    else:
        print("\nAll modules imported successfully.")
        sys.exit(0)
