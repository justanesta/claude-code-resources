# Django Web Application

## Project Type
Python web application using Django framework for production-ready web services.

## Project-Specific Standards

### Framework & Structure
- Django project structure with apps
- Settings split: base.py, development.py, production.py
- Environment variables managed via python-decouple or django-environ
- PostgreSQL for production, SQLite for development/testing

### Testing Strategy
- pytest-django for all tests
- Factory Boy for test fixtures
- Coverage target: 80% minimum
- Test categories:
  - Unit: Models, forms, serializers
  - Integration: Views, API endpoints
  - End-to-end: Critical user flows (consider pytest-playwright)

### API Development (if applicable)
- Django REST Framework for APIs
- API versioning via URL path (e.g., /api/v1/)
- Serializer validation with custom validators
- Token or JWT authentication

### Code Quality
- Type hints with pyright
- Pydantic for data validation (especially for external API interactions)
- ruff for linting and formatting
- Pre-commit hooks recommended

### Documentation Requirements
- README.md: Project overview, quick start, core features
- documentation/
  - architecture.md: Django apps, database schema, key design decisions
  - api.md: API endpoints, request/response examples (if applicable)
  - development.md: Local setup, running tests, migrations
  - deployment.md: Production deployment steps, environment variables

### Django-Specific Practices
- Always create migrations with descriptive names
- Use Django's built-in User model or extend AbstractUser (not AbstractBaseUser unless necessary)
- Querysets: Use select_related() and prefetch_related() to avoid N+1 queries
- Use Django's form validation, don't bypass it
- Keep business logic in models/services, not views

### Dependencies
- Use requirements.txt with pinned versions OR pyproject.toml with poetry/hatch
- Separate: requirements-dev.txt for development dependencies

### Quality Gates (Before Next Feature)
- [ ] Feature works locally and in staging-like environment
- [ ] Unit and integration tests passing
- [ ] API documentation updated (if applicable)
- [ ] Migrations created and tested
- [ ] ruff linting passes
- [ ] pyright type checking passes
- [ ] Documentation updated

### Cost Considerations
- Start with free tier: Render, Railway, or Fly.io for hosting
- PostgreSQL: Supabase or Neon free tier
- Static files: Whitenoise (serves from Django, no CDN cost)