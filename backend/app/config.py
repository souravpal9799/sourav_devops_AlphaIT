from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    AWS_REGION: str = "us-east-1"
    SECRET_NAME: str = "rds-db-credentials"
    DB_HOST: str = ""
    DB_PORT: int = 3306
    DB_NAME: str = "mvp_db"

    class Config:
        env_file = ".env"

settings = Settings()
