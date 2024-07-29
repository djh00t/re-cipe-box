#!/bin/bash

# Set variables
PROJECT_NAME="recipe_box"
GIT_REPO="git@github.com:djh00t/recipe_box.git"  # Replace with your actual Git repo URL
TMDB_API_KEY="eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJlNTU0NDQ3ZDc3ZWE3ODFmNzhkMDkwYzc2Yzc3YzQ4MiIsIm5iZiI6MTcyMTk0NjIwNy45OTg2NDcsInN1YiI6IjU4ZDIxZTEzYzNhMzY4MzhjOTAxOWNhOSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.E51PMmP3-CL53H_LRyAbnBiZsRSH4WV3r4UZA1NugAQ"
MYSQL_ROOT_PASSWORD="supersecret"
MYSQL_DB="recipe_box"
MYSQL_USER="recipe_box"
MYSQL_PASSWORD="supersecret"

# Create project directory
mkdir $PROJECT_NAME
cd $PROJECT_NAME

# Initialize Git repository
git init
git remote add origin $GIT_REPO

# Create .env file
cat <<EOL > .env
TMDB_API_KEY=$TMDB_API_KEY
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DB=$MYSQL_DB
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOL

# Create Dockerfile
cat <<EOL > Dockerfile
FROM python:3.11-bookworm

# Install necessary dependencies
RUN pip install fastapi uvicorn requests sqlalchemy pymysql alembic

# Set environment variables
ENV TMDB_API_KEY=""
ENV MYSQL_HOST=""
ENV MYSQL_PORT=""
ENV MYSQL_USER=""
ENV MYSQL_PASSWORD=""
ENV MYSQL_DB=""

# Copy the application code
COPY . /app

# Set the working directory
WORKDIR /app

# Expose port 8000
EXPOSE 8000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOL

# Create docker-compose.yml
cat <<EOL > docker-compose.yml
services:
  db:
    image: mysql:latest
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DB}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - db_data:/var/lib/mysql

  api:
    build: .
    environment:
      TMDB_API_KEY: \${TMDB_API_KEY}
      MYSQL_HOST: db
      MYSQL_PORT: 3306
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
      MYSQL_DB: \${MYSQL_DB}
    depends_on:
      - db
    ports:
      - "8000:8000"

volumes:
  db_data:
EOL

# Create main.py
mkdir -p app
cat <<EOL > app/main.py
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, Column, Integer, String, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
import requests

DATABASE_URL = f"mysql+pymysql://{os.getenv('MYSQL_USER')}:{os.getenv('MYSQL_PASSWORD')}@{os.getenv('MYSQL_HOST')}:{os.getenv('MYSQL_PORT')}/{os.getenv('MYSQL_DB')}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

app = FastAPI()

class Movie(Base):
    __tablename__ = "movies"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    used = Column(Boolean, default=False)

def init_db():
    Base.metadata.create_all(bind=engine)

@app.on_event("startup")
def on_startup():
    init_db()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/movies/")
def read_movies(db: Session = Depends(get_db)):
    return db.query(Movie).all()

@app.post("/movies/")
def create_movie(title: str, db: Session = Depends(get_db)):
    movie = Movie(title=title)
    db.add(movie)
    db.commit()
    db.refresh(movie)
    return movie

@app.put("/movies/{movie_id}")
def update_movie(movie_id: int, used: bool, db: Session = Depends(get_db)):
    movie = db.query(Movie).filter(Movie.id == movie_id).first()
    if not movie:
        raise HTTPException(status_code=404, detail="Movie not found")
    movie.used = used
    db.commit()
    return movie

@app.get("/search_movies/")
def search_movies(genre: str, db: Session = Depends(get_db)):
    api_key = os.getenv("TMDB_API_KEY")
    url = f"https://api.themoviedb.org/3/discover/movie?api_key={api_key}&with_genres={genre}"
    response = requests.get(url)
    movies = response.json().get('results', [])
    for movie in movies:
        if not db.query(Movie).filter(Movie.title == movie['title']).first():
            create_movie(title=movie['title'], db=db)
    return movies
EOL

# Create Alembic directory and initial migration script
mkdir -p alembic/versions
cat <<EOL > alembic.ini
[alembic]
script_location = alembic

[alembic:env]
SQLALCHEMY_URL = mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}
EOL

cat <<EOL > alembic/env.py
from alembic import context
from sqlalchemy import create_engine, pool
from sqlalchemy.ext.declarative import declarative_base
import os

DATABASE_URL = f"mysql+pymysql://{os.getenv('MYSQL_USER')}:{os.getenv('MYSQL_PASSWORD')}@{os.getenv('MYSQL_HOST')}:{os.getenv('MYSQL_PORT')}/{os.getenv('MYSQL_DB')}"

engine = create_engine(DATABASE_URL, poolclass=pool.NullPool)
Base = declarative_base()

def run_migrations_offline():
    context.configure(
        url=DATABASE_URL, target_metadata=Base.metadata, literal_binds=True
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=Base.metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOL

cat <<EOL > alembic/versions/initial_migration.py
from alembic import op
import sqlalchemy as sa

revision = 'initial_migration'
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        'movies',
        sa.Column('id', sa.Integer, primary_key=True),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('used', sa.Boolean, default=False)
    )

def downgrade():
    op.drop_table('movies')
EOL

cat <<EOL > alembic/versions/__init__.py
# Just an empty init file for alembic versions
EOL

# Initialize and configure Alembic
alembic init alembic
alembic revision --autogenerate -m "Initial migration"
alembic upgrade head

# Add all files to Git
git add .
git commit -m "Initial commit"
git push -u origin master

echo "Setup complete. You can now run 'docker-compose up --build' to start your application."
