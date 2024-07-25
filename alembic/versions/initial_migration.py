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
