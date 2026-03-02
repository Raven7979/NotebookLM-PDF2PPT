from paddleocr import PaddleOCR
import time

print("Starting PaddleOCR initialization check...")
start = time.time()
try:
    # Try initializing (this triggers auto-download if missing)
    app = PaddleOCR(use_angle_cls=True, lang='ch')
    print(f"✅ PaddleOCR initialized successfully in {time.time() - start:.2f} seconds.")
except Exception as e:
    print(f"❌ PaddleOCR initialization failed: {e}")
