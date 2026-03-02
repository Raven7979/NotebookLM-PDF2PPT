import os
import sys

# Add backend to path
# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from backend.core.converter import PDFToPPTConverter

def test_conversion():
    # Setup paths
    # Assuming we run this from the project root or backend dir
    pdf_path = "mock_upload.pdf" 
    output_path = "test_output.pptx"
    
    # Check for test PDF, create dummy if not exists
    if not os.path.exists(pdf_path):
        from PIL import Image
        img = Image.new('RGB', (100, 100), color = (73, 109, 137))
        img.save('temp_img.jpg')
        img.save('mock_upload.pdf', "PDF", resolution=100.0)
        pdf_path = 'mock_upload.pdf'
        
    print(f"Testing conversion of {pdf_path}...")
    
    # Initialize with MOCK key
    os.environ["NANO_API_KEY"] = "mock_key_for_dry_run"
    
    converter = PDFToPPTConverter(api_key="mock_key_for_dry_run")
    
    try:
        converter.convert(pdf_path, output_path)
        print("Conversion SUCCESS")
    except Exception as e:
        print(f"Conversion FAILED (Expected if mock key used): {e}")
        # Identify failure point
        if "Nano API Error" in str(e) or "401" in str(e) or "Unauthorized" in str(e):
             print("Verified: Pipeline reached Nano API call.")

if __name__ == "__main__":
    test_conversion()
