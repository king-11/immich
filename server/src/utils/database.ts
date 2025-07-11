import {
  DeduplicateJoinsPlugin,
  Expression,
  ExpressionBuilder,
  ExpressionWrapper,
  Kysely,
  KyselyConfig,
  Nullable,
  Selectable,
  SelectQueryBuilder,
  Simplify,
  sql,
} from 'kysely';
import { PostgresJSDialect } from 'kysely-postgres-js';
import { jsonArrayFrom, jsonObjectFrom } from 'kysely/helpers/postgres';
import { parse } from 'pg-connection-string';
import postgres, { Notice } from 'postgres';
import { columns, Exif, Person } from 'src/database';
import { AssetFileType, AssetVisibility, DatabaseExtension, DatabaseSslMode } from 'src/enum';
import { AssetSearchBuilderOptions } from 'src/repositories/search.repository';
import { DB } from 'src/schema';
import { DatabaseConnectionParams, VectorExtension } from 'src/types';

type Ssl = 'require' | 'allow' | 'prefer' | 'verify-full' | boolean | object;

const isValidSsl = (ssl?: string | boolean | object): ssl is Ssl =>
  typeof ssl !== 'string' || ssl === 'require' || ssl === 'allow' || ssl === 'prefer' || ssl === 'verify-full';

export const asPostgresConnectionConfig = (params: DatabaseConnectionParams) => {
  if (params.connectionType === 'parts') {
    return {
      host: params.host,
      port: params.port,
      username: params.username,
      password: params.password,
      database: params.database,
      ssl: params.ssl === DatabaseSslMode.Disable ? false : params.ssl,
    };
  }

  const { host, port, user, password, database, ...rest } = parse(params.url);
  let ssl: Ssl | undefined;
  if (rest.ssl) {
    if (!isValidSsl(rest.ssl)) {
      throw new Error(`Invalid ssl option: ${rest.ssl}`);
    }
    ssl = rest.ssl;
  }

  return {
    host: host ?? undefined,
    port: port ? Number(port) : undefined,
    username: user,
    password,
    database: database ?? undefined,
    ssl,
  };
};

export const getKyselyConfig = (
  params: DatabaseConnectionParams,
  options: Partial<postgres.Options<Record<string, postgres.PostgresType>>> = {},
): KyselyConfig => {
  const config = asPostgresConnectionConfig(params);

  return {
    dialect: new PostgresJSDialect({
      postgres: postgres({
        onnotice: (notice: Notice) => {
          if (notice['severity'] !== 'NOTICE') {
            console.warn('Postgres notice:', notice);
          }
        },
        max: 10,
        types: {
          date: {
            to: 1184,
            from: [1082, 1114, 1184],
            serialize: (x: Date | string) => (x instanceof Date ? x.toISOString() : x),
            parse: (x: string) => new Date(x),
          },
          bigint: {
            to: 20,
            from: [20, 1700],
            parse: (value: string) => Number.parseInt(value),
            serialize: (value: number) => value.toString(),
          },
        },
        connection: {
          TimeZone: 'UTC',
        },
        host: config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        database: config.database,
        ssl: config.ssl,
        ...options,
      }),
    }),
    log(event) {
      if (event.level === 'error') {
        console.error('Query failed :', {
          durationMs: event.queryDurationMillis,
          error: event.error,
          sql: event.query.sql,
          params: event.query.parameters,
        });
      }
    },
  };
};

export const asUuid = (id: string | Expression<string>) => sql<string>`${id}::uuid`;

export const anyUuid = (ids: string[]) => sql<string>`any(${`{${ids}}`}::uuid[])`;

export const asVector = (embedding: number[]) => sql<string>`${`[${embedding}]`}::vector`;

export const unnest = (array: string[]) => sql<Record<string, string>>`unnest(array[${sql.join(array)}]::text[])`;

export const removeUndefinedKeys = <T extends object>(update: T, template: unknown) => {
  for (const key in update) {
    if ((template as T)[key] === undefined) {
      delete update[key];
    }
  }

  return update;
};

/** Modifies toJson return type to not set all properties as nullable */
export function toJson<DB, TB extends keyof DB & string, T extends TB | Expression<unknown>>(
  eb: ExpressionBuilder<DB, TB>,
  table: T,
) {
  return eb.fn.toJson<T>(table) as ExpressionWrapper<
    DB,
    TB,
    Simplify<
      T extends TB
        ? Selectable<DB[T]> extends Nullable<infer N>
          ? N | null
          : Selectable<DB[T]>
        : T extends Expression<infer O>
          ? O extends Nullable<infer N>
            ? N | null
            : O
          : never
    >
  >;
}

export const ASSET_CHECKSUM_CONSTRAINT = 'UQ_assets_owner_checksum';

export function withDefaultVisibility<O>(qb: SelectQueryBuilder<DB, 'assets', O>) {
  return qb.where('assets.visibility', 'in', [sql.lit(AssetVisibility.ARCHIVE), sql.lit(AssetVisibility.TIMELINE)]);
}

// TODO come up with a better query that only selects the fields we need
export function withExif<O>(qb: SelectQueryBuilder<DB, 'assets', O>) {
  return qb
    .leftJoin('exif', 'assets.id', 'exif.assetId')
    .select((eb) => eb.fn.toJson(eb.table('exif')).$castTo<Exif | null>().as('exifInfo'));
}

export function withExifInner<O>(qb: SelectQueryBuilder<DB, 'assets', O>) {
  return qb
    .innerJoin('exif', 'assets.id', 'exif.assetId')
    .select((eb) => eb.fn.toJson(eb.table('exif')).$castTo<Exif>().as('exifInfo'));
}

export function withSmartSearch<O>(qb: SelectQueryBuilder<DB, 'assets', O>) {
  return qb
    .leftJoin('smart_search', 'assets.id', 'smart_search.assetId')
    .select((eb) => toJson(eb, 'smart_search').as('smartSearch'));
}

export function withFaces(eb: ExpressionBuilder<DB, 'assets'>, withDeletedFace?: boolean) {
  return jsonArrayFrom(
    eb
      .selectFrom('asset_faces')
      .selectAll('asset_faces')
      .whereRef('asset_faces.assetId', '=', 'assets.id')
      .$if(!withDeletedFace, (qb) => qb.where('asset_faces.deletedAt', 'is', null)),
  ).as('faces');
}

export function withFiles(eb: ExpressionBuilder<DB, 'assets'>, type?: AssetFileType) {
  return jsonArrayFrom(
    eb
      .selectFrom('asset_files')
      .select(columns.assetFiles)
      .whereRef('asset_files.assetId', '=', 'assets.id')
      .$if(!!type, (qb) => qb.where('asset_files.type', '=', type!)),
  ).as('files');
}

export function withFacesAndPeople(eb: ExpressionBuilder<DB, 'assets'>, withDeletedFace?: boolean) {
  return jsonArrayFrom(
    eb
      .selectFrom('asset_faces')
      .leftJoinLateral(
        (eb) =>
          eb.selectFrom('person').selectAll('person').whereRef('asset_faces.personId', '=', 'person.id').as('person'),
        (join) => join.onTrue(),
      )
      .selectAll('asset_faces')
      .select((eb) => eb.table('person').$castTo<Person>().as('person'))
      .whereRef('asset_faces.assetId', '=', 'assets.id')
      .$if(!withDeletedFace, (qb) => qb.where('asset_faces.deletedAt', 'is', null)),
  ).as('faces');
}

export function hasPeople<O>(qb: SelectQueryBuilder<DB, 'assets', O>, personIds: string[]) {
  return qb.innerJoin(
    (eb) =>
      eb
        .selectFrom('asset_faces')
        .select('assetId')
        .where('personId', '=', anyUuid(personIds!))
        .where('deletedAt', 'is', null)
        .groupBy('assetId')
        .having((eb) => eb.fn.count('personId').distinct(), '=', personIds.length)
        .as('has_people'),
    (join) => join.onRef('has_people.assetId', '=', 'assets.id'),
  );
}

export function inAlbums<O>(qb: SelectQueryBuilder<DB, 'assets', O>, albumIds: string[]) {
  return qb.innerJoin(
    (eb) =>
      eb
        .selectFrom('albums_assets_assets')
        .select('assetsId')
        .where('albumsId', '=', anyUuid(albumIds!))
        .groupBy('assetsId')
        .having((eb) => eb.fn.count('albumsId').distinct(), '=', albumIds.length)
        .as('has_album'),
    (join) => join.onRef('has_album.assetsId', '=', 'assets.id'),
  );
}

export function hasTags<O>(qb: SelectQueryBuilder<DB, 'assets', O>, tagIds: string[]) {
  return qb.innerJoin(
    (eb) =>
      eb
        .selectFrom('tag_asset')
        .select('assetsId')
        .innerJoin('tags_closure', 'tag_asset.tagsId', 'tags_closure.id_descendant')
        .where('tags_closure.id_ancestor', '=', anyUuid(tagIds))
        .groupBy('assetsId')
        .having((eb) => eb.fn.count('tags_closure.id_ancestor').distinct(), '>=', tagIds.length)
        .as('has_tags'),
    (join) => join.onRef('has_tags.assetsId', '=', 'assets.id'),
  );
}

export function withOwner(eb: ExpressionBuilder<DB, 'assets'>) {
  return jsonObjectFrom(eb.selectFrom('users').select(columns.user).whereRef('users.id', '=', 'assets.ownerId')).as(
    'owner',
  );
}

export function withLibrary(eb: ExpressionBuilder<DB, 'assets'>) {
  return jsonObjectFrom(
    eb.selectFrom('libraries').selectAll('libraries').whereRef('libraries.id', '=', 'assets.libraryId'),
  ).as('library');
}

export function withTags(eb: ExpressionBuilder<DB, 'assets'>) {
  return jsonArrayFrom(
    eb
      .selectFrom('tags')
      .select(columns.tag)
      .innerJoin('tag_asset', 'tags.id', 'tag_asset.tagsId')
      .whereRef('assets.id', '=', 'tag_asset.assetsId'),
  ).as('tags');
}

export function truncatedDate<O>() {
  return sql<O>`date_trunc(${sql.lit('MONTH')}, "localDateTime" AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'`;
}

export function withTagId<O>(qb: SelectQueryBuilder<DB, 'assets', O>, tagId: string) {
  return qb.where((eb) =>
    eb.exists(
      eb
        .selectFrom('tags_closure')
        .innerJoin('tag_asset', 'tag_asset.tagsId', 'tags_closure.id_descendant')
        .whereRef('tag_asset.assetsId', '=', 'assets.id')
        .where('tags_closure.id_ancestor', '=', tagId),
    ),
  );
}

const joinDeduplicationPlugin = new DeduplicateJoinsPlugin();
/** TODO: This should only be used for search-related queries, not as a general purpose query builder */

export function searchAssetBuilder(kysely: Kysely<DB>, options: AssetSearchBuilderOptions) {
  options.withDeleted ||= !!(options.trashedAfter || options.trashedBefore || options.isOffline);
  const visibility = options.visibility == null ? AssetVisibility.TIMELINE : options.visibility;

  return kysely
    .withPlugin(joinDeduplicationPlugin)
    .selectFrom('assets')
    .where('assets.visibility', '=', visibility)
    .$if(!!options.albumIds && options.albumIds.length > 0, (qb) => inAlbums(qb, options.albumIds!))
    .$if(!!options.tagIds && options.tagIds.length > 0, (qb) => hasTags(qb, options.tagIds!))
    .$if(options.tagIds === null, (qb) =>
      qb.where((eb) => eb.not(eb.exists((eb) => eb.selectFrom('tag_asset').whereRef('assetsId', '=', 'assets.id')))),
    )
    .$if(!!options.personIds && options.personIds.length > 0, (qb) => hasPeople(qb, options.personIds!))
    .$if(!!options.createdBefore, (qb) => qb.where('assets.createdAt', '<=', options.createdBefore!))
    .$if(!!options.createdAfter, (qb) => qb.where('assets.createdAt', '>=', options.createdAfter!))
    .$if(!!options.updatedBefore, (qb) => qb.where('assets.updatedAt', '<=', options.updatedBefore!))
    .$if(!!options.updatedAfter, (qb) => qb.where('assets.updatedAt', '>=', options.updatedAfter!))
    .$if(!!options.trashedBefore, (qb) => qb.where('assets.deletedAt', '<=', options.trashedBefore!))
    .$if(!!options.trashedAfter, (qb) => qb.where('assets.deletedAt', '>=', options.trashedAfter!))
    .$if(!!options.takenBefore, (qb) => qb.where('assets.fileCreatedAt', '<=', options.takenBefore!))
    .$if(!!options.takenAfter, (qb) => qb.where('assets.fileCreatedAt', '>=', options.takenAfter!))
    .$if(options.city !== undefined, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where('exif.city', options.city === null ? 'is' : '=', options.city!),
    )
    .$if(options.state !== undefined, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where('exif.state', options.state === null ? 'is' : '=', options.state!),
    )
    .$if(options.country !== undefined, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where('exif.country', options.country === null ? 'is' : '=', options.country!),
    )
    .$if(options.make !== undefined, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where('exif.make', options.make === null ? 'is' : '=', options.make!),
    )
    .$if(options.model !== undefined, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where('exif.model', options.model === null ? 'is' : '=', options.model!),
    )
    .$if(options.lensModel !== undefined, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where('exif.lensModel', options.lensModel === null ? 'is' : '=', options.lensModel!),
    )
    .$if(options.rating !== undefined, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where('exif.rating', options.rating === null ? 'is' : '=', options.rating!),
    )
    .$if(!!options.checksum, (qb) => qb.where('assets.checksum', '=', options.checksum!))
    .$if(!!options.deviceAssetId, (qb) => qb.where('assets.deviceAssetId', '=', options.deviceAssetId!))
    .$if(!!options.deviceId, (qb) => qb.where('assets.deviceId', '=', options.deviceId!))
    .$if(!!options.id, (qb) => qb.where('assets.id', '=', asUuid(options.id!)))
    .$if(!!options.libraryId, (qb) => qb.where('assets.libraryId', '=', asUuid(options.libraryId!)))
    .$if(!!options.userIds, (qb) => qb.where('assets.ownerId', '=', anyUuid(options.userIds!)))
    .$if(!!options.encodedVideoPath, (qb) => qb.where('assets.encodedVideoPath', '=', options.encodedVideoPath!))
    .$if(!!options.originalPath, (qb) =>
      qb.where(sql`f_unaccent(assets."originalPath")`, 'ilike', sql`'%' || f_unaccent(${options.originalPath}) || '%'`),
    )
    .$if(!!options.originalFileName, (qb) =>
      qb.where(
        sql`f_unaccent(assets."originalFileName")`,
        'ilike',
        sql`'%' || f_unaccent(${options.originalFileName}) || '%'`,
      ),
    )
    .$if(!!options.description, (qb) =>
      qb
        .innerJoin('exif', 'assets.id', 'exif.assetId')
        .where(sql`f_unaccent(exif.description)`, 'ilike', sql`'%' || f_unaccent(${options.description}) || '%'`),
    )
    .$if(!!options.type, (qb) => qb.where('assets.type', '=', options.type!))
    .$if(options.isFavorite !== undefined, (qb) => qb.where('assets.isFavorite', '=', options.isFavorite!))
    .$if(options.isOffline !== undefined, (qb) => qb.where('assets.isOffline', '=', options.isOffline!))
    .$if(options.isEncoded !== undefined, (qb) =>
      qb.where('assets.encodedVideoPath', options.isEncoded ? 'is not' : 'is', null),
    )
    .$if(options.isMotion !== undefined, (qb) =>
      qb.where('assets.livePhotoVideoId', options.isMotion ? 'is not' : 'is', null),
    )
    .$if(!!options.isNotInAlbum && (!options.albumIds || options.albumIds.length === 0), (qb) =>
      qb.where((eb) =>
        eb.not(eb.exists((eb) => eb.selectFrom('albums_assets_assets').whereRef('assetsId', '=', 'assets.id'))),
      ),
    )
    .$if(!!options.withExif, withExifInner)
    .$if(!!(options.withFaces || options.withPeople || options.personIds), (qb) => qb.select(withFacesAndPeople))
    .$if(!options.withDeleted, (qb) => qb.where('assets.deletedAt', 'is', null));
}

export type ReindexVectorIndexOptions = { indexName: string; lists?: number };

type VectorIndexQueryOptions = { table: string; vectorExtension: VectorExtension } & ReindexVectorIndexOptions;

export function vectorIndexQuery({ vectorExtension, table, indexName, lists }: VectorIndexQueryOptions): string {
  switch (vectorExtension) {
    case DatabaseExtension.VECTORCHORD: {
      return `
        CREATE INDEX IF NOT EXISTS ${indexName} ON ${table} USING vchordrq (embedding vector_cosine_ops) WITH (options = $$
        residual_quantization = false
        [build.internal]
        lists = [${lists ?? 1}]
        spherical_centroids = true
        build_threads = 4
        sampling_factor = 1024
        $$)`;
    }
    case DatabaseExtension.VECTORS: {
      return `
        CREATE INDEX IF NOT EXISTS ${indexName} ON ${table}
        USING vectors (embedding vector_cos_ops) WITH (options = $$
        optimizing.optimizing_threads = 4
        [indexing.hnsw]
        m = 16
        ef_construction = 300
        $$)`;
    }
    case DatabaseExtension.VECTOR: {
      return `
        CREATE INDEX IF NOT EXISTS ${indexName} ON ${table}
        USING hnsw (embedding vector_cosine_ops)
        WITH (ef_construction = 300, m = 16)`;
    }
    default: {
      throw new Error(`Unsupported vector extension: '${vectorExtension}'`);
    }
  }
}
