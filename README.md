# SplitSmart

A Splitwise-like expense sharing mobile application built using Flutter and Golang.

## Features
- Group-based expense sharing
- Bill attachments (image / PDF)
- Strict expense ownership rules
- Request-based approval workflow
- UPI payment redirection
- Swipe-based expense navigation

## Tech Stack
- Flutter (Riverpod, GoRouter)
- Golang (REST APIs)
- PostgreSQL
- JWT Authentication

## Architecture
- Flutter feature-based architecture
- Go `cmd` pattern for server
- Request-driven expense mutation model

## How to Run
### Backend
cd server  
go mod tidy  
go run cmd/srv/main.go  

### Mobile
flutter pub get  
flutter run
