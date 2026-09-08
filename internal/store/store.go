package store

import (
	"fmt"
	"log/slog"

	"github.com/glebarez/sqlite"
	"github.com/hwview/hwview/config"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type Store struct {
	DB *gorm.DB
}

func New(cfg *config.DatabaseConfig) (*Store, error) {
	var db *gorm.DB
	var err error
	gormCfg := &gorm.Config{Logger: logger.Default.LogMode(logger.Warn)}

	switch cfg.Driver {
	case "sqlite":
		db, err = gorm.Open(sqlite.Open(cfg.DSN), gormCfg)
	case "postgres":
		db, err = gorm.Open(postgres.Open(cfg.DSN), gormCfg)
	default:
		return nil, fmt.Errorf("unsupported database driver: %s", cfg.Driver)
	}
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	slog.Info("database connected", "driver", cfg.Driver)
	return &Store{DB: db}, nil
}

func (s *Store) AutoMigrate() error {
	return s.DB.AutoMigrate(
		&model.ProductionLine{},
		&model.DataSource{},
		&model.ProductionRecord{},
		&model.CollectCursor{},
		&model.DataSourceHealth{},
		&model.Agent{},
		&model.AuditLog{},
		&model.CartonSpecification{},
		&model.DailyProductionPlan{},
		&model.HolidayCalendar{},
	)
}

func (s *Store) Close() error {
	sqlDB, err := s.DB.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}
