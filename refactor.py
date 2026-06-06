import os
import re

ROOT_DIR = '/mnt/project/SapaPNJ/lib'
EXCLUDE_FILES = ['frosted_glass.dart']

# Regexes to find and replace widget constructors
# We only want to replace widget instantiations, e.g. `AppBar(` but not `SliverAppBar(`
# Also we need to make sure we don't replace `FrostedAppBar(` -> `FrostedFrostedAppBar(`
REPLACEMENTS = {
    r'(?<!\w)AppBar\s*\(': 'FrostedAppBar(',
    r'(?<!\w)BottomNavigationBar\s*\(': 'FrostedBottomNavBar(',
    r'(?<!\w)Card\s*\(': 'FrostedCard(',
    r'(?<!\w)FloatingActionButton\s*\(': 'FrostedFAB(',
    r'(?<!\w)Drawer\s*\(': 'FrostedDrawer(',
}

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    modified = False

    for pattern, replacement in REPLACEMENTS.items():
        if re.search(pattern, content):
            content = re.sub(pattern, replacement, content)
            modified = True

    # If we made replacements, ensure the frosted_glass.dart import is present
    if modified:
        # Calculate relative path to frosted_glass.dart
        # E.g. if file is lib/screens/home.dart, depth is 1, so import '../widgets/frosted_glass.dart'
        rel_path = os.path.relpath('/mnt/project/SapaPNJ/lib/widgets/frosted_glass.dart', os.path.dirname(filepath))
        import_stmt = f"import '{rel_path}';"
        
        if import_stmt not in content:
            # find the last import and insert after it, or top of file
            imports = list(re.finditer(r'^import\s+.*?;', content, re.MULTILINE))
            if imports:
                last_import = imports[-1]
                content = content[:last_import.end()] + '\n' + import_stmt + content[last_import.end():]
            else:
                content = import_stmt + '\n' + content
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

def main():
    for root, dirs, files in os.walk(ROOT_DIR):
        for file in files:
            if file.endswith('.dart') and file not in EXCLUDE_FILES:
                process_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
