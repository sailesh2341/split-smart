package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/sailesh2341/splitsmart-server/middleware"
)

type UserHandler struct {
	DB *sql.DB
}

func (h *UserHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserIDFromContext(r.Context())

	var name, email string
	err := h.DB.QueryRow(
		`SELECT name, email FROM users WHERE id=$1`,
		userID,
	).Scan(&name, &email)

	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"id":    userID,
		"name":  name,
		"email": email,
	})
}
