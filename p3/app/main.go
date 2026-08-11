package main

import (
	"log"

	"github.com/gofiber/fiber/v3"
)

// Заполняются на этапе сборки через -ldflags "-X main.lastCommit=... -X main.version=..."
var (
	lastCommit = "unknown"
	version    = "dev"
)

func main() {
	app := fiber.New()

	app.Get("/", func(c fiber.Ctx) error {
		return c.JSON(struct {
			LastCommit string `json:"lastCommit"`
			Version    string `json:"version"`
			Status     string `json:"status"`
		}{
			LastCommit: lastCommit,
			Version:    version,
			Status:     "ok",
		})
	})

	log.Fatal(app.Listen(":8080"))
}
