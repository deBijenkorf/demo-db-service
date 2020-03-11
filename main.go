package main

import (
	"database/sql"
	"fmt"
	_ "github.com/lib/pq"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handler(w http.ResponseWriter, r *http.Request) {
	// Get the PostgreSQL connection string from the environment.
	connection := os.Getenv("DEMO_POSTGRES_CONNECTION") // Example: "host=localhost port=5432 user=postgres password=postgres dbname=demo sslmode=disable"

	// Open the database connection.
	db, err := sql.Open("postgres", connection)
	if err != nil {
		panic(err)
	}
	defer db.Close() // Make sure we close the database connection when we're done with it.

	// Query the database.
	query := "SELECT name FROM names;"
	rows, err := db.Query(query)
	if err != nil {
		panic(err)
	}

	// Loop over the resulting rows and print a message for each.
	name := "dummy"
	for rows.Next() {
		err := rows.Scan(&name)
		if err != nil {
			panic(err)
		}
		fmt.Fprintf(w, "Hello %s!\n", name)
	}
}
