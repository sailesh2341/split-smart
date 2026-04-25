package db

import (
	"database/sql"

	_ "github.com/lib/pq"
)

func Connect() (*sql.DB, error) {
	return sql.Open(
		"postgres",
		"postgres://user:password@localhost:5432/splitsmart?sslmode=disable",
	)
}
