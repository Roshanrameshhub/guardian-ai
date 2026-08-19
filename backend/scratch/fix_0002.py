import os

file_path = "c:/dev/guardian-ai/backend/alembic/versions/0002_add_safety_and_police_tables.py"

with open(file_path, "r") as f:
    content = f.read()

# Add Inspector import
content = content.replace("from sqlalchemy.dialects.postgresql import UUID\n", "from sqlalchemy.dialects.postgresql import UUID\nfrom sqlalchemy import inspect\n")

# Modify upgrade function
upgrade_start = content.find("def upgrade() -> None:")
upgrade_end = content.find("def downgrade() -> None:")

upgrade_content = content[upgrade_start:upgrade_end]

# We want to conditionally create the tables
new_upgrade_content = """def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    # ── police_stations ────────────────────────────────────────────────────────
    if not inspector.has_table('police_stations'):
        op.create_table(
            'police_stations',
            sa.Column('id', UUID(as_uuid=False), primary_key=True),
            sa.Column('city', sa.String(100), nullable=False, server_default='Chennai'),
            sa.Column('zone', sa.String(100), nullable=False),
            sa.Column('sub_division', sa.String(150), nullable=False),
            sa.Column('station_name', sa.String(255), nullable=False),
            sa.Column('contact_number', sa.String(100), nullable=False),
            sa.Column('address', sa.String(500), nullable=True),
            sa.Column('latitude', sa.Float, nullable=True),
            sa.Column('longitude', sa.Float, nullable=True),
            sa.Column(
                'source_info',
                sa.String(500),
                nullable=False,
                server_default='Chennai Police Department directory - informational prototype data',
            ),
            sa.Column('is_verified', sa.Boolean, nullable=False, server_default=sa.false()),
            sa.Column(
                'created_at',
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text('now()'),
            ),
        )
        op.create_index('ix_police_stations_city', 'police_stations', ['city'])
        op.create_index('ix_police_stations_zone', 'police_stations', ['zone'])
        op.create_index('ix_police_stations_sub_division', 'police_stations', ['sub_division'])
        op.create_index('ix_police_stations_station_name', 'police_stations', ['station_name'])
        op.create_index('ix_police_stations_latitude', 'police_stations', ['latitude'])
        op.create_index('ix_police_stations_longitude', 'police_stations', ['longitude'])

    # ── safety_zones ───────────────────────────────────────────────────────────
    if not inspector.has_table('safety_zones'):
        op.create_table(
            'safety_zones',
            sa.Column('id', sa.String(50), primary_key=True),           # e.g. 'CHN001'
            sa.Column('place', sa.String(255), nullable=False),
            sa.Column('category', sa.String(100), nullable=False),
            sa.Column('anchor_area', sa.String(150), nullable=False),
            sa.Column('demo_safety_label', sa.String(100), nullable=False),
            sa.Column('day_risk_score', sa.Integer, nullable=False),
            sa.Column('night_risk_score', sa.Integer, nullable=False),
            sa.Column('route_risk_score', sa.Integer, nullable=False),
            sa.Column('footfall', sa.String(50), nullable=False),
            sa.Column('night_activity', sa.String(50), nullable=False),
            sa.Column('lighting', sa.String(50), nullable=False),
            sa.Column('isolation', sa.String(50), nullable=False),
            sa.Column('recommendation', sa.String(500), nullable=False),
            sa.Column('data_status', sa.String(255), nullable=False),
            sa.Column('source_basis', sa.String(1000), nullable=False),
            sa.Column('crime_data', sa.String(255), nullable=False),
            sa.Column('use_for_routing', sa.Boolean, nullable=False, server_default=sa.true()),
            sa.Column('geocode_query', sa.String(500), nullable=False),
            sa.Column('demo_safety_score', sa.Integer, nullable=False),
            sa.Column('latitude', sa.Float, nullable=False),
            sa.Column('longitude', sa.Float, nullable=False),
            sa.Column('radius_meters', sa.Float, nullable=False, server_default='600.0'),
            sa.Column(
                'created_at',
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text('now()'),
            ),
        )
        op.create_index('ix_safety_zones_place', 'safety_zones', ['place'])
        op.create_index('ix_safety_zones_anchor_area', 'safety_zones', ['anchor_area'])
        op.create_index('ix_safety_zones_day_risk_score', 'safety_zones', ['day_risk_score'])
        op.create_index('ix_safety_zones_night_risk_score', 'safety_zones', ['night_risk_score'])
        op.create_index('ix_safety_zones_demo_safety_score', 'safety_zones', ['demo_safety_score'])
        op.create_index('ix_safety_zones_latitude', 'safety_zones', ['latitude'])
        op.create_index('ix_safety_zones_longitude', 'safety_zones', ['longitude'])

"""

content = content.replace(upgrade_content, new_upgrade_content)

with open(file_path, "w") as f:
    f.write(content)
