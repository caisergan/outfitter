# Branch-only wardrobe tests kept commented out for now.
#
# from unittest.mock import patch
#
# import pytest
# from httpx import AsyncClient
#
#
# async def _signup(
#     client: AsyncClient,
#     email: str = "wardrobe@outfitter.dev",
#     password: str = "supersecret99",
# ):
#     return await client.post("/auth/signup", json={"email": email, "password": password})
#
#
# @pytest.mark.asyncio
# async def test_wardrobe_image_upload_url_returns_presigned_target(client: AsyncClient):
#     signup_resp = await _signup(client)
#     token = signup_resp.json()["access_token"]
#
#     with patch("app.routers.wardrobe.get_wardrobe_upload_target") as mock_target:
#         mock_target.return_value.upload_url = "https://s3.amazonaws.com/presigned-put"
#         mock_target.return_value.image_url = (
#             "https://bucket.s3.us-east-1.amazonaws.com/wardrobe/u1/image.jpg"
#         )
#         mock_target.return_value.key = "wardrobe/u1/image.jpg"
#
#         response = await client.post(
#             "/wardrobe/images/upload-url",
#             headers={"Authorization": f"Bearer {token}"},
#             json={
#                 "filename": "image.jpg",
#                 "content_type": "image/jpeg",
#                 "file_size": 2048,
#             },
#         )
#
#     assert response.status_code == 200
#     body = response.json()
#     assert body["image_url"] == "https://bucket.s3.us-east-1.amazonaws.com/wardrobe/u1/image.jpg"
#     assert body["object_key"] == "wardrobe/u1/image.jpg"
#
#
# @pytest.mark.asyncio
# async def test_wardrobe_image_upload_url_rejects_invalid_content_type(client: AsyncClient):
#     signup_resp = await _signup(client, email="wardrobe-invalid@outfitter.dev")
#     token = signup_resp.json()["access_token"]
#
#     response = await client.post(
#         "/wardrobe/images/upload-url",
#         headers={"Authorization": f"Bearer {token}"},
#         json={
#             "filename": "image.gif",
#             "content_type": "image/gif",
#             "file_size": 2048,
#         },
#     )
#
#     assert response.status_code == 422
#
#
# @pytest.mark.asyncio
# async def test_wardrobe_image_upload_url_returns_502_on_storage_error(client: AsyncClient):
#     signup_resp = await _signup(client, email="wardrobe-storage-err@outfitter.dev")
#     token = signup_resp.json()["access_token"]
#
#     from app.services.storage_service import StorageError
#
#     with patch("app.routers.wardrobe.get_wardrobe_upload_target") as mock_target:
#         mock_target.side_effect = StorageError("S3 unavailable")
#
#         response = await client.post(
#             "/wardrobe/images/upload-url",
#             headers={"Authorization": f"Bearer {token}"},
#             json={
#                 "filename": "image.jpg",
#                 "content_type": "image/jpeg",
#                 "file_size": 2048,
#             },
#         )
#
#     assert response.status_code == 502
#
#
# @pytest.mark.asyncio
# async def test_wardrobe_upload_url_expiry_matches_shared_policy(client: AsyncClient):
#     signup_resp = await _signup(client, email="wardrobe-expiry@outfitter.dev")
#     token = signup_resp.json()["access_token"]
#
#     with patch("app.routers.wardrobe.get_wardrobe_upload_target") as mock_target:
#         mock_target.return_value.upload_url = "https://s3.amazonaws.com/presigned-put"
#         mock_target.return_value.image_url = "https://bucket.s3.amazonaws.com/wardrobe/u1/img.jpg"
#         mock_target.return_value.key = "wardrobe/u1/img.jpg"
#
#         response = await client.post(
#             "/wardrobe/images/upload-url",
#             headers={"Authorization": f"Bearer {token}"},
#             json={
#                 "filename": "img.jpg",
#                 "content_type": "image/jpeg",
#                 "file_size": 2048,
#             },
#         )
#
#     assert response.status_code == 200
#     assert response.json()["expires_in"] == 900
#
#
# @pytest.mark.asyncio
# async def test_wardrobe_image_upload_url_accepts_webp(client: AsyncClient):
#     signup_resp = await _signup(client, email="wardrobe-webp@outfitter.dev")
#     token = signup_resp.json()["access_token"]
#
#     with patch("app.routers.wardrobe.get_wardrobe_upload_target") as mock_target:
#         mock_target.return_value.upload_url = "https://s3.amazonaws.com/presigned-put"
#         mock_target.return_value.image_url = "https://bucket.s3.amazonaws.com/wardrobe/u1/img.webp"
#         mock_target.return_value.key = "wardrobe/u1/img.webp"
#
#         response = await client.post(
#             "/wardrobe/images/upload-url",
#             headers={"Authorization": f"Bearer {token}"},
#             json={
#                 "filename": "img.webp",
#                 "content_type": "image/webp",
#                 "file_size": 2048,
#             },
#         )
#
#     assert response.status_code == 200
#
#
# @pytest.mark.asyncio
# async def test_create_wardrobe_item_rejects_external_image_url_before_fetch(client: AsyncClient):
#     signup_resp = await _signup(client, email="wardrobe-external-url@outfitter.dev")
#     token = signup_resp.json()["access_token"]
#
#     response = await client.post(
#         "/wardrobe",
#         headers={"Authorization": f"Bearer {token}"},
#         json={
#             "category": "top",
#             "image_url": "https://example.com/not-managed.jpg",
#         },
#     )
#
#     assert response.status_code == 422
#     assert "managed wardrobe storage URL" in response.json()["detail"]
#
#
# @pytest.mark.asyncio
# async def test_create_wardrobe_item_accepts_current_users_managed_storage_url(client: AsyncClient):
#     signup_resp = await _signup(client, email="wardrobe-managed-url@outfitter.dev")
#     token = signup_resp.json()["access_token"]
#     user_id = signup_resp.json()["user"]["id"]
#     managed_url = f"https://outfitter-media.s3.us-east-1.amazonaws.com/wardrobe/{user_id}/shirt.jpg"
#
#     response = await client.post(
#         "/wardrobe",
#         headers={"Authorization": f"Bearer {token}"},
#         json={
#             "category": "top",
#             "image_url": managed_url,
#         },
#     )
#
#     assert response.status_code == 201
