package main

import (
	"log/slog"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/config"
	"github.com/hwview/hwview/internal/server"
	"github.com/hwview/hwview/internal/store"
	"github.com/hwview/hwview/pkg/adapters"
	adapterbuiltin "github.com/hwview/hwview/pkg/adapters/builtin"
)

func main() {
	cfg, err := config.Load("config/config.yaml")
	if err != nil {
		slog.Error("failed to load config", "err", err)
		os.Exit(1)
	}

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	adapterReg := adapters.NewRegistry()
	adapterbuiltin.RegisterBuiltins(adapterReg)

	dbStore, err := store.New(&cfg.Database)
	if err != nil {
		slog.Error("failed to init store", "err", err)
		os.Exit(1)
	}
	if err := dbStore.AutoMigrate(); err != nil {
		slog.Error("failed to migrate", "err", err)
		os.Exit(1)
	}

	gin.SetMode(cfg.Server.Mode)
	router := gin.New()

	appServer := server.New(cfg, adapterReg, dbStore.DB)
	if err := appServer.RegisterRoutes(router); err != nil {
		slog.Error("failed to register routes", "err", err)
		os.Exit(1)
	}

	addr := cfg.Server.Host + ":" + cfg.Server.Port
	slog.Info("hwview-server starting", "addr", addr)
	if err := router.Run(addr); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}
