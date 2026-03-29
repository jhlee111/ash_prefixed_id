# Changelog

## 0.1.0

Forked from [ash_object_ids](https://github.com/drtheuns/ash_object_ids) and renamed to `AshPrefixedId`.

### Added

- `AnyPrefixedId` type — a universal `:uuid` replacement that accepts any prefixed ID or raw UUID
- `to_uuid!/1` and `to_uuid_string!/1` for converting prefixed IDs to raw UUID formats
- `to_prefixed_id/2` for converting UUIDs back to prefixed form
- `find_resource_for_prefix/2` and `find_resource_for_id/2` for resource lookup by prefix
- `find_duplicate_prefixes/1` and `map_prefixes_to_resources/1` for prefix management
- `PostgresExtension` with `uuid_generate_v7()` for server-side UUIDv7 generation
- `migration_default?` option for automatic PostgreSQL migration defaults
- Automatic `belongs_to` foreign key type inference via `BelongsToAttribute` transformer

### Changed

- Renamed `AshObjectIds` → `AshPrefixedId` throughout
- Moved FK type updates from transformer to persister for reliability
- Improved handling of self-referential foreign keys
- Fixed 16-byte binary handling in `cast_stored`
- Fixed binary-to-string UUID conversion in `cast_input`
