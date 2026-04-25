package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

type GroupHandler struct {
	DB *sql.DB
}

type GroupResponse struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type GroupMemberResponse struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
	Role  string `json:"role"`
}

type createGroupRequest struct {
	Name string `json:"name"`
}

type addGroupMemberRequest struct {
	Email string `json:"email"`
}

func (h *GroupHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	rows, err := h.DB.Query(
		`SELECT g.id, g.name
		 FROM groups g
		 JOIN group_members gm ON gm.group_id = g.id
		 WHERE gm.user_id = $1
		 ORDER BY g.created_at DESC`,
		userID,
	)
	if err != nil {
		http.Error(w, "Failed to load groups", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	groups := []GroupResponse{}
	for rows.Next() {
		var group GroupResponse
		if err := rows.Scan(&group.ID, &group.Name); err != nil {
			http.Error(w, "Failed to parse groups", http.StatusInternalServerError)
			return
		}
		groups = append(groups, group)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(groups)
}

func (h *GroupHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	var req createGroupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, "Failed to create group", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	group := GroupResponse{ID: uuid.New().String(), Name: req.Name}
	if _, err := tx.Exec(
		`INSERT INTO groups (id, name, created_by) VALUES ($1, $2, $3)`,
		group.ID,
		group.Name,
		userID,
	); err != nil {
		http.Error(w, "Failed to create group", http.StatusInternalServerError)
		return
	}

	if _, err := tx.Exec(
		`INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'owner')`,
		group.ID,
		userID,
	); err != nil {
		http.Error(w, "Failed to add group member", http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, "Failed to save group", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(group)
}

func (h *GroupHandler) AddMember(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	groupID := mux.Vars(r)["groupId"]

	var req addGroupMemberRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	var canAdd bool
	if err := h.DB.QueryRow(
		`SELECT EXISTS(
			SELECT 1 FROM groups
			WHERE id = $1 AND created_by = $2
		)`,
		groupID,
		userID,
	).Scan(&canAdd); err != nil || !canAdd {
		http.Error(w, "Only the group owner can add members", http.StatusForbidden)
		return
	}

	var memberID string
	if err := h.DB.QueryRow(
		`SELECT id FROM users WHERE email = $1`,
		req.Email,
	).Scan(&memberID); err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	if _, err := h.DB.Exec(
		`INSERT INTO group_members (group_id, user_id, role)
		 VALUES ($1, $2, 'member')
		 ON CONFLICT (group_id, user_id) DO NOTHING`,
		groupID,
		memberID,
	); err != nil {
		http.Error(w, "Failed to add member", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ADDED"})
}

func (h *GroupHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	groupID := mux.Vars(r)["groupId"]

	var canView bool
	if err := h.DB.QueryRow(
		`SELECT EXISTS(
			SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2
		)`,
		groupID,
		userID,
	).Scan(&canView); err != nil || !canView {
		http.Error(w, "Group not found", http.StatusNotFound)
		return
	}

	rows, err := h.DB.Query(
		`SELECT u.id, u.name, u.email, gm.role
		 FROM group_members gm
		 JOIN users u ON u.id = gm.user_id
		 WHERE gm.group_id = $1
		 ORDER BY gm.role DESC, u.name`,
		groupID,
	)
	if err != nil {
		http.Error(w, "Failed to load members", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	members := []GroupMemberResponse{}
	for rows.Next() {
		var member GroupMemberResponse
		if err := rows.Scan(
			&member.ID,
			&member.Name,
			&member.Email,
			&member.Role,
		); err != nil {
			http.Error(w, "Failed to parse members", http.StatusInternalServerError)
			return
		}
		members = append(members, member)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(members)
}
