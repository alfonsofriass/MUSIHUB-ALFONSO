from fastapi import FastAPI

from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router

app = FastAPI(title="MusiHub API")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(api_router)


@app.get("/")
def read_root() -> dict[str, str]:
    return {"message": "MusiHub API is running"}
