import io
import logging
from PIL import Image
from rembg import remove, new_session

logger = logging.getLogger(__name__)

# Initialize the rembg session at module load.
# 'u2net' is the standard model for fine-grained salient object detection.
session = new_session("u2net")

def clean_and_crop_image(image_bytes: bytes) -> bytes:
    """
    Removes the image background using rembg.
    Crops the transparent margins around the garment to focus the object.
    Returns the cleaned image as PNG bytes.
    """
    try:
        input_image = Image.open(io.BytesIO(image_bytes))
        
        # 1. Remove background (Yields an RGBA image where background is transparent)
        output_image = remove(input_image, session=session)
        
        # 2. Crop empty space (Get bounding box of non-alpha pixels)
        # Bounding box is a 4-tuple defining the left, upper, right, and lower pixel coordinate.
        bbox = output_image.getbbox()
        if bbox:
            output_image = output_image.crop(bbox)
        else:
            logger.warning("Image blank after bg removal. Bounding box not found.")
            
        # 3. Save as PNG to preserve transparency
        buf = io.BytesIO()
        output_image.save(buf, format="PNG")
        return buf.getvalue()
        
    except Exception as e:
        logger.error(f"Image cleaning failed: {e}")
        # If removal fails, fallback to original image to not break the pipeline.
        return image_bytes
