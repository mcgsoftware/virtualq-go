package main

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	testPostgresConnection()
}

// Connects to Neon postgresql database to make sure it can connect.
func testPostgresConnection() {

	connStr := "postgresql://neondb_owner:npg_D7g2KtYkwRoZ@ep-crimson-star-ahtrlu3u-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

	// Create connection pool
	pool, err := pgxpool.New(context.Background(), connStr)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	// Test the connection
	var version string
	err = pool.QueryRow(context.Background(), "SELECT version()").Scan(&version)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Successfully connected to Neon!")
	fmt.Println("PostgreSQL version:", version)
}
