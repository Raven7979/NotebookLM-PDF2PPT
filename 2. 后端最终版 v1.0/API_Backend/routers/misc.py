from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.orm import Session
from typing import List, Optional
import shutil
import os
from database import get_db
import models, schemas, crud
from datetime import datetime

router = APIRouter(
    tags=["misc"]
)

# App Version Endpoints

@router.get("/app/latest", response_model=schemas.AppVersion)
def get_latest_version(db: Session = Depends(get_db)):
    """
    Get the latest app version info for auto-update checks.
    """
    version = crud.get_latest_app_version(db)
    if not version:
        raise HTTPException(status_code=404, detail="No version info found")
    return version

@router.get("/app/versions", response_model=List[schemas.AppVersion])
def get_all_versions(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db)
    # current_user: models.User = Depends(auth.get_current_active_superuser) # TODO: Add auth later if needed
):
    """
    Get all app versions (Admin only ideally).
    """
    return crud.get_app_versions(db, skip=skip, limit=limit)

@router.post("/app/versions", response_model=schemas.AppVersion)
async def create_new_version(
    version: str = Form(...),
    build: int = Form(...),
    release_notes: Optional[str] = Form(None),
    force_update: bool = Form(False),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
    # current_user: models.User = Depends(auth.get_current_active_superuser) # TODO: Add auth later
):
    """
    Upload a new app version (Admin only).
    """
    # 1. Validate file extension
    if not (file.filename.endswith(".dmg") or file.filename.endswith(".pkg")):
        raise HTTPException(status_code=400, detail="Only .dmg or .pkg files are allowed")

    # 2. Save file
    upload_dir = "uploads/versions"
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename to avoid conflicts
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    safe_filename = f"{version}_{build}_{timestamp}_{file.filename}"
    file_path = os.path.join(upload_dir, safe_filename)
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"File upload failed: {str(e)}")

    # 3. Generate Download URL
    # Assuming backend is served at base URL. We need to construct the full URL or relative path.
    # For simplicity, we return the relative path which the frontend/app can prepend with base URL.
    # Or, if we have a configured DOMAIN env var, we use that.
    # Let's use a relative path like /static/versions/... that Nginx/FastAPI serves.
    # We will mount "uploads" dir to "/uploads" path in main.py
    download_url = f"/uploads/versions/{safe_filename}"

    # 4. Create DB Record
    version_create = schemas.AppVersionCreate(
        version=version,
        build=build,
        release_notes=release_notes,
        force_update=force_update
    )
    
    return crud.create_app_version(db, version=version_create, download_url=download_url, local_file_path=file_path)

@router.delete("/app/versions/{version_id}")
def delete_version(
    version_id: int, 
    db: Session = Depends(get_db)
    # current_user: models.User = Depends(auth.get_current_active_superuser)
):
    """
    Delete a version and its file.
    """
    # Get version to find file path
    version = db.query(models.AppVersion).filter(models.AppVersion.id == version_id).first()
    if not version:
        raise HTTPException(status_code=404, detail="Version not found")
        
    # Delete file
    if version.local_file_path and os.path.exists(version.local_file_path):
        try:
            os.remove(version.local_file_path)
        except Exception as e:
            print(f"Error deleting file {version.local_file_path}: {e}")

    # Delete DB record
    if crud.delete_app_version(db, version_id):
        return {"detail": "Version deleted"}
    
    raise HTTPException(status_code=400, detail="Failed to delete version")
