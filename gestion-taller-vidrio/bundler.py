import os

# Configuración
root_dir = '.'
output_file = 'AppCodebase.txt'
extensions = ['.swift']
# Carpetas a ignorar (ajusta según necesites)
ignore_dirs = {'.git', '.build', 'DerivedData', 'Tests', 'UITests', 'Preview Content'}

def is_ignored(path):
    parts = path.split(os.sep)
    for part in parts:
        if part in ignore_dirs:
            return True
    return False

with open(output_file, 'w', encoding='utf-8') as outfile:
    for root, dirs, files in os.walk(root_dir):
        if is_ignored(root):
            continue
            
        for file in files:
            if any(file.endswith(ext) for ext in extensions):
                file_path = os.path.join(root, file)
                
                # Escribir cabecera clara para el LLM
                outfile.write(f"\n{'='*60}\n")
                outfile.write(f"FILE_PATH: {file_path}\n")
                outfile.write(f"{'='*60}\n\n")
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as infile:
                        outfile.write(infile.read())
                except Exception as e:
                    outfile.write(f"Error reading file: {e}\n")
                
                outfile.write("\n")

print(f"Listo. Todo el código está en {output_file}. Súbelo al chat.")