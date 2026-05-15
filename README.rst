nycharealtalk
=========

This is the code behind nycharealtalk.org. It is built upon the
`Living Lots <https://github.com/596acres/django-livinglots>`_ ® framework by `596 Acres <https://596acres.org>`_ ®,
originally developed for nycommons.org.


Development setup
-----------------

Prerequisites: `Docker <https://docs.docker.com/get-docker/>`_ with Compose.

 1. Clone this repo locally.
 2. Copy the environment file and fill in values::

      cp .env.example .env

    The defaults in ``.env.example`` work for local Docker development.
    ``NYCHAREALTALK_SECRET_KEY`` and ``NYCHAREALTALK_ORGANIZE_PARTICIPANT_SALT``
    should be set to non-empty strings.

 3. Start the database and run migrations::

      docker compose up -d db
      docker compose run --rm web python manage.py migrate

    If ``migrate`` fails with a ``column already exists`` error, the database
    has partial state from a previous run. Fake the usercontent migrations and
    retry::

      docker compose run --rm web python manage.py migrate usercontent --fake
      docker compose run --rm web python manage.py migrate

 4. Create the PostGIS views that TileStache reads::

      docker compose exec db psql -U nycharealtalk nycharealtalk \
          -f /docker-entrypoint-initdb.d/create-views.sql

 5. Create a superuser::

      docker compose run --rm web python manage.py createsuperuser

 6. Start all services::

      docker compose up

    The site runs at http://localhost:8000. Map tiles are served at
    http://localhost:8080. The database is accessible from the host on port 5434.

 7. Build the frontend assets (in a separate terminal, from ``nycharealtalk/static/``)::

      npm install
      npm run css:dev   # compile LESS once
      npm run dev       # watch and rebuild JS on changes

    For a one-shot production build::

      npm run build

Loading a database snapshot
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To restore a production or staging dump into the Docker database::

    docker compose exec -T db pg_restore -U nycharealtalk -d nycharealtalk --disable-triggers --no-owner < dump.dump

After restoring, re-run the TileStache views step above since they may not be
included in the dump.


Production deployment
---------------------

See the comments at the top of ``docker-compose.prod.yml`` for the full
first-time setup and subsequent deploy steps. In brief:

 1. Copy ``.env.example`` to ``.env.prod`` and fill in all values, including
    the production-only variables listed in ``docker-compose.prod.yml``.

 2. All ``docker compose`` commands for production require both flags::

      docker compose -f docker-compose.prod.yml --env-file .env.prod <command>

 3. On first deploy, run migrations and collect static files, then run
    ``docker/init-letsencrypt.sh`` to obtain SSL certificates and start all
    services.

 4. To switch between staging (``dev.nycharealtalk.org``) and production
    (``nycharealtalk.org``), update ``NYCHAREALTALK_DOMAIN`` and
    ``NYCHAREALTALK_TILES_DOMAIN`` in ``.env.prod`` and rebuild.


Organization
------------


License
-------

GNU Affero General Public License. See LICENSE.
