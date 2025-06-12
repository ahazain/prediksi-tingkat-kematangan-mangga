import os
import shutil

# Path ke cache YOLOv5
cache_path = r"C:\Users\ACER\.cache\torch\hub\ultralytics_yolov5_master"

if os.path.exists(cache_path):
    try:
        shutil.rmtree(cache_path)
        print(f"Cache deleted successfully: {cache_path}")
    except Exception as e:
        print(f"Error deleting cache: {e}")
else:
    print("Cache directory not found")

# Juga hapus file zip jika ada
zip_path = r"C:\Users\ACER\.cache\torch\hub\master.zip"
if os.path.exists(zip_path):
    try:
        os.remove(zip_path)
        print(f"Zip file deleted: {zip_path}")
    except Exception as e:
        print(f"Error deleting zip: {e}")

print("Cache cleanup completed!")