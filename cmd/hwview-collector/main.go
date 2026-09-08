package main

import (
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/hwview/hwview/config"
	"github.com/hwview/hwview/internal/collector"
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

	interval, err := time.ParseDuration(cfg.Collector.CollectionInterval)
	if err != nil {
		slog.Error("invalid collection_interval", "value", cfg.Collector.CollectionInterval, "err", err)
		os.Exit(1)
	}

	sched := collector.NewScheduler(interval, cfg, adapterReg, dbStore.DB)

	stopCh := make(chan os.Signal, 1)
	signal.Notify(stopCh, syscall.SIGINT, syscall.SIGTERM)

	slog.Info("hwview-collector starting", "interval", interval)
	sched.Start()

	<-stopCh
	slog.Info("hwview-collector stopping")
	sched.Stop()
	slog.Info("hwview-collector stopped")
}
