from pydantic import BaseModel, EmailStr, Field


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, description="Minimum 8 characters")


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
