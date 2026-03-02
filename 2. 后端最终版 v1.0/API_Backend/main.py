import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import models, schemas, crud, database
from routers import admin, codes, users, mac, pay, auth
from services.file_service import FileService
from core.converter import PDFToPPTConverter
import shutil
import os
from urllib.parse import quote
from dotenv import load_dotenv
load_dotenv()

# Create DB tables
models.Base.metadata.create_all(bind=database.engine)

ENV = os.getenv("ENV", "development")
app = FastAPI(
    title="NotePDF 2 PPT Backend",
    docs_url="/docs" if ENV == "development" else None,
    redoc_url="/redoc" if ENV == "development" else None
)

# Constants
GENERATED_DIR = "generated_pptx"
os.makedirs(GENERATED_DIR, exist_ok=True)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from fastapi.staticfiles import StaticFiles
app.mount("/static", StaticFiles(directory="static"), name="static")

# Dependency
def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

app.include_router(admin.router)
app.include_router(codes.router)
app.include_router(users.router)
app.include_router(mac.router)
app.include_router(pay.router)
app.include_router(auth.router)
from routers import misc
app.include_router(misc.router, prefix="/api/v1/misc")

# Mount uploads directory for static file serving
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# Health check
@app.get("/api/health")
def health_check():
    return {"status": "ok", "version": "2.0.0"}

# Auth Endpoints are now in routers/auth.py

# File Upload & Processing Endpoints

@app.post("/api/upload")
async def upload_file(
    file: UploadFile = File(...),
    phone_number: str = Form(...),
    db: Session = Depends(get_db)
):
    """
    Upload PDF file, count pages, calculate cost.
    Does NOT deduct credits yet.
    """
    # 1. Get User
    user = crud.get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 2. Save File & Analyze
    try:
        file_path = await FileService.save_upload_file(file)
        page_count = FileService.get_pdf_page_count(file_path)
        cost = FileService.calculate_cost(page_count)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    # 3. Create File Record
    file_record_in = schemas.FileRecordCreate(
        filename=file.filename,
        file_path=file_path,
        page_count=page_count,
        cost=cost,
        user_id=user.phone_number
    )
    file_record = crud.create_file_record(db, file_record_in)

    return {
        "file_id": file_record.id,
        "filename": file_record.filename,
        "page_count": file_record.page_count,
        "cost": file_record.cost,
        "message": "File uploaded successfully. Please confirm conversion."
    }

@app.post("/api/convert")
def convert_file(request: schemas.ConvertRequest, db: Session = Depends(get_db)):
    """
    Deduct credits and start conversion.
    """
    # 1. Get User & File
    user = crud.get_user_by_phone(db, request.phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    file_record = crud.get_file_record(db, request.file_id)
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found")
        
    # Verify ownership
    if file_record.user_id != user.phone_number:
        raise HTTPException(status_code=403, detail="Not authorized to convert this file")

    if file_record.status != "uploaded":
         return {
            "message": "File already processed or processing",
            "remaining_credits": user.credits,
            "status": file_record.status
        }

    # 2. Check Balance
    if user.credits < file_record.cost:
        raise HTTPException(
            status_code=400, 
            detail=f"Insufficient credits. Need {file_record.cost}, have {user.credits}"
        )

    # 3. Deduct Credits
    user.credits -= file_record.cost
    
    # --- Generation Logic ---
    # 使用 Core Converter 模块进行转换
    # 这样未来只需更新 backend/core/converter.py 即可同步 Mac App 的核心算法
    
    base_name = os.path.splitext(file_record.filename)[0]
    output_filename = f"{base_name}.pptx"
    output_path = os.path.join(GENERATED_DIR, f"{file_record.id}.pptx") # Store by ID to avoid collisions
    
    try:
        api_key = os.getenv("NANO_API_KEY")
        converter = PDFToPPTConverter(api_key=api_key)
        converter.convert(file_record.file_path, output_path)
        file_record.status = "completed"
    except Exception as e:
        print(f"Error during conversion: {e}")
        # 回滚积分扣除 (可选)
        user.credits += file_record.cost
        file_record.status = "failed"
        db.commit()
        raise HTTPException(status_code=500, detail=f"Conversion failed: {str(e)}")
    
    # -----------------------

    db.commit()
    db.refresh(user)
    db.refresh(file_record)

    return {
        "message": "Conversion successful",
        "remaining_credits": user.credits,
        "file_id": file_record.id,
        "download_url": f"/api/download/{file_record.id}"
    }

@app.get("/api/download/{file_id}")
def download_file(file_id: str, db: Session = Depends(get_db)):
    file_record = crud.get_file_record(db, file_id)
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found")
        
    file_path = os.path.join(GENERATED_DIR, f"{file_id}.pptx")
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not generated")

    # Determine download filename
    base_name = os.path.splitext(file_record.filename)[0]
    download_filename = f"{base_name}.pptx"
    
    # URL encode filename for Content-Disposition
    encoded_filename = quote(download_filename)
    
    return FileResponse(
        path=file_path, 
        filename=download_filename,
        media_type="application/vnd.openxmlformats-officedocument.presentationml.presentation",
        headers={"Content-Disposition": f"attachment; filename*=utf-8''{encoded_filename}"}
    )

# --- DEBUG & STATIC MOUNT ---

# Request logging middleware for debugging
@app.middleware("http")
async def log_requests(request, call_next):
    import time
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    print(f"DEBUG: {request.method} {request.url.path} status={response.status_code} duration={duration:.2f}s")
    return response

# Static files for React frontend
# MOUNTED LAST to ensure all API routes have priority.
if os.path.exists("dist"):
    app.mount("/", StaticFiles(directory="dist", html=True), name="dist")


