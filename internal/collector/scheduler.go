package collector

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/hwview/hwview/config"
	"github.com/hwview/hwview/pkg/adapters"
	"gorm.io/gorm"
)

type Scheduler struct {
	interval   time.Duration
	cfg        *config.Config
	adapterReg *adapters.Registry
	db         *gorm.DB
	collector  *IncrementalCollector
	healthMon  *HealthMonitor
	stopCh     chan struct{}
	wg         sync.WaitGroup
}

func NewScheduler(interval time.Duration, cfg *config.Config, adapterReg *adapters.Registry, db *gorm.DB) *Scheduler {
	resolver := NewSourceResolver(db, adapterReg)
	recordRepo := newSchedulerRecordRepo(db)
	collector := NewIncrementalCollector(db, resolver, recordRepo)
	healthMon := NewHealthMonitor(db, cfg.Health.ConsecutiveFailuresThreshold, cfg.Health.OfflineThreshold)
	return &Scheduler{
		interval:   interval,
		cfg:        cfg,
		adapterReg: adapterReg,
		db:         db,
		collector:  collector,
		healthMon:  healthMon,
		stopCh:     make(chan struct{}),
	}
}

func (s *Scheduler) Start() {
	s.wg.Add(1)
	go s.run()
}

func (s *Scheduler) run() {
	defer s.wg.Done()
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()
	s.collectOnce()
	for {
		select {
		case <-ticker.C:
			s.collectOnce()
		case <-s.stopCh:
			return
		}
	}
}

func (s *Scheduler) collectOnce() {
	ctx := context.Background()
	slog.Info("collection tick started", "interval", s.interval)
	if err := s.collector.CollectAll(ctx); err != nil {
		slog.Error("collection tick failed", "err", err)
	}
	slog.Info("collection tick completed")
}

func (s *Scheduler) Stop() {
	close(s.stopCh)
	s.wg.Wait()
}
