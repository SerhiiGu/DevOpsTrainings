package main

import (
	"github.com/gofiber/fiber/v2"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/gofiber/adaptor/v2"
)

func main() {
	app := fiber.New()

	
	app.EnableProxyHeaders()

	app.Get("/", func(c *fiber.Ctx) error {
		return c.SendString("Hello from Go App 🐹")
	})

	app.Get("/metrics", adaptor.HTTPHandler(promhttp.Handler()))

	app.Listen(":4000")
}
