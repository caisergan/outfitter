from app.routers.auth import router as auth
from app.routers.catalog import router as catalog
from app.routers.wardrobe import router as wardrobe
from app.routers.outfits import router as outfits
from app.routers.tryon import router as tryon
from app.routers.storage import router as storage

__all__ = ["auth", "catalog", "wardrobe", "outfits", "tryon", "storage"]
