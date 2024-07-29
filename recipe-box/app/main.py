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
