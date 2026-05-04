from fastapi import FastAPI

from app.api.router import api_router

app = FastAPI(title="MusiHub API")
app.include_router(api_router)


@app.get("/")
def read_root() -> dict[str, str]:
    return {"message": "MusiHub API is running"}
