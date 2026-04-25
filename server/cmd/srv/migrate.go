package main

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"
	"sort"
)

func runMigrations(db *sql.DB) error {
	migrationsDir := "db/migrations"

	files, err := os.ReadDir(migrationsDir)
	if err != nil {
		return err
	}

	var migrationFiles []string
	for _, f := range files {
		if filepath.Ext(f.Name()) == ".sql" {
			migrationFiles = append(migrationFiles, f.Name())
		}
	}

	sort.Strings(migrationFiles)

	for _, file := range migrationFiles {
		path := filepath.Join(migrationsDir, file)

		sqlBytes, err := os.ReadFile(path)
		if err != nil {
			return err
		}

		if _, err := db.Exec(string(sqlBytes)); err != nil {
			return err
		}

		log.Printf("applied migration: %s", file)
	}

	return nil
}
