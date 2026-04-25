package main

import (
	"database/sql"
	"log"
	"net/http"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"

	"github.com/sailesh2341/splitsmart-server/handlers"
)

func main() {
	db, err := sql.Open(
		"postgres",
		"postgres://splitsmart:splitsmart@postgres:5432/splitsmart?sslmode=disable",
	)
	if err != nil {
		log.Fatal(err)
	}

	if err := db.Ping(); err != nil {
		log.Fatal(err)
	}

	// Run migrations.
	if err := runMigrations(db); err != nil {
		log.Fatal(err)
	}

	router := mux.NewRouter()
	router.PathPrefix("/uploads/").Handler(
		http.StripPrefix("/uploads/", http.FileServer(http.Dir("uploads"))),
	)

	// Health.
	router.HandleFunc("/health", handlers.HealthHandler).Methods("GET")

	// Auth.
	authHandler := &handlers.AuthHandler{DB: db}
	router.HandleFunc("/auth/register", authHandler.Register).Methods("POST")
	router.HandleFunc("/auth/login", authHandler.Login).Methods("POST")

	// Protected routes.
	api := router.PathPrefix("/api").Subrouter()
	api.Use(handlers.JWTMiddleware)

	meHandler := &handlers.MeHandler{DB: db}
	api.HandleFunc("/me", meHandler.Me).Methods("GET")

	groupHandler := &handlers.GroupHandler{DB: db}
	api.HandleFunc("/groups", groupHandler.List).Methods("GET")
	api.HandleFunc("/groups", groupHandler.Create).Methods("POST")
	api.HandleFunc("/groups/{groupId}/members", groupHandler.AddMember).Methods("POST")
	api.HandleFunc("/groups/{groupId}/members", groupHandler.ListMembers).Methods("GET")

	uploadHandler := &handlers.UploadHandler{Dir: "uploads"}
	api.HandleFunc("/uploads", uploadHandler.Upload).Methods("POST")

	expenseHandler := &handlers.ExpenseHandler{DB: db}
	api.HandleFunc("/groups/{groupId}/expenses", expenseHandler.List).Methods("GET")
	api.HandleFunc("/groups/{groupId}/expenses", expenseHandler.Create).Methods("POST")
	api.HandleFunc("/groups/{groupId}/order-types", expenseHandler.OrderTypes).Methods("GET")
	api.HandleFunc("/expenses/{expenseId}/mark-paid", expenseHandler.MarkPaid).Methods("POST")

	requestHandler := &handlers.RequestHandler{DB: db}
	api.HandleFunc("/expenses/{expenseId}/requests", requestHandler.Create).Methods("POST")
	api.HandleFunc("/requests", requestHandler.ListForOwner).Methods("GET")
	api.HandleFunc("/requests/{requestId}/approve", requestHandler.Approve).Methods("POST")
	api.HandleFunc("/requests/{requestId}/reject", requestHandler.Reject).Methods("POST")

	log.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", router))
}
