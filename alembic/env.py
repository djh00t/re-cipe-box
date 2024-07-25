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
