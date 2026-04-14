import {
  pgTable,
  uuid,
  date,
  boolean,
  text,
  timestamp,
  unique,
  index,
} from 'drizzle-orm/pg-core'

// ── challenge_progress ────────────────────────────────────────────────────────
// Tägliche Check-ins für Challenges.
// Eine Zeile pro User + Challenge + Datum (UNIQUE-Constraint).
export const challengeProgress = pgTable(
  'challenge_progress',
  {
    id: uuid('id')
      .primaryKey()
      .defaultRandom(),

    challengeId: uuid('challenge_id')
      .notNull(),
    //  .references(() => challenges.id, { onDelete: 'cascade' })
    //  challenges-Tabelle hier nicht importiert um zirkuläre Deps zu vermeiden

    userId: uuid('user_id')
      .notNull(),
    //  .references(() => authUsers.id, { onDelete: 'cascade' })

    date: date('date')
      .notNull()
      .$defaultFn(() => new Date().toISOString().split('T')[0]),

    checkedIn: boolean('checked_in')
      .notNull()
      .default(false),

    proofImageUrl: text('proof_image_url'),

    verifiedByAdmin: boolean('verified_by_admin')
      .notNull()
      .default(false),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    // Eindeutiger Eintrag pro User + Challenge + Tag
    unique('uq_challenge_progress_user_date').on(
      table.challengeId,
      table.userId,
      table.date,
    ),
    // Performance-Indizes
    index('idx_cp_challenge_user').on(table.challengeId, table.userId),
    index('idx_cp_user_date').on(table.userId, table.date),
    index('idx_cp_challenge_date').on(table.challengeId, table.date),
  ],
)

// ── Abgeleitete TypeScript-Typen ─────────────────────────────────────────────
export type ChallengeProgress        = typeof challengeProgress.$inferSelect
export type NewChallengeProgress     = typeof challengeProgress.$inferInsert
