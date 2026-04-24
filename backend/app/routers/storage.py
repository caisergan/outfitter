from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, Query

from app.auth.jwt import get_current_user
from app.models.user import User
from app.services import storage_service

router = APIRouter(prefix="/storage", tags=["storage"])

CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.get("/upload-url")
async def get_upload_url(
    current_user: CurrentUserDep,
    file_extension: Annotated[str, Query()] = "png",
) -> dict:
    """
    Returns a pre-signed URL for a user to upload a wardrobe image directly to R2.
    The object key follow wardrobe/{user_id}/{item_id}.{ext}
    """
    item_id = str(uuid4())
    # Presigned URLs are useful for allowing frontend to upload directly to R2
    # without passing the large binary through our API server again.
    upload_url = storage_service.get_upload_url(str(current_user.id), item_id)
    
    # storage_service.get_upload_url always uses .jpg in its implementation, 
    # but we can return the target object key for the frontend to reference later.
    file_key = f"wardrobe/{current_user.id}/{item_id}.jpg"
    
    return {
        "upload_url": upload_url,
        "file_key": file_key,
        "item_id": item_id
    }
