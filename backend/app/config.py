from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # These hardcoded values act as defaults.
    # Pydantic will automatically override them
    # if they are found in the environment variables,
    # or if they are defined inside a `.env` file.
    AWS_REGION: str = "ap-south-1"
    SECRET_NAME: str = "rds-db-creds"

    DB_HOST: str = ""
    DB_PORT: int = 3306
    DB_NAME: str = "demo_db"
    DB_USER: str = ""
    DB_PASSWORD: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
