package collector

import (
	"context"
	"time"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

type HealthMonitor struct {
	db                *gorm.DB
	degradedThreshold int
	offlineThreshold  int
}

func NewHealthMonitor(db *gorm.DB, degradedThreshold, offlineThreshold int) *HealthMonitor {
	return &HealthMonitor{db: db, degradedThreshold: degradedThreshold, offlineThreshold: offlineThreshold}
}

func (m *HealthMonitor) RecordSuccess(ctx context.Context, sourceID int64) error {
	now := time.Now()
	return m.db.WithContext(ctx).Model(&model.DataSourceHealth{}).
		Where("source_id = ?", sourceID).
		Updates(map[string]interface{}{
			"status":               model.SourceStatusOnline,
			"last_success_at":      now,
			"consecutive_failures": 0,
			"last_error":           "",
			"updated_at":           now,
		}).Error
}

func (m *HealthMonitor) RecordFailure(ctx context.Context, sourceID int64, errMsg string) error {
	now := time.Now()
	var health model.DataSourceHealth
	if err := m.db.WithContext(ctx).Where("source_id = ?", sourceID).First(&health).Error; err != nil {
		health = model.DataSourceHealth{SourceID: sourceID, Status: model.SourceStatusOffline}
	}

	health.ConsecutiveFailures++
	health.LastFailureAt = &now
	health.LastError = errMsg

	health.Status = m.computeStatus(health.ConsecutiveFailures)
	health.UpdatedAt = now

	return m.db.WithContext(ctx).Save(&health).Error
}

func (m *HealthMonitor) computeStatus(consecutiveFailures int) string {
	if consecutiveFailures >= m.offlineThreshold {
		return model.SourceStatusOffline
	}
	if consecutiveFailures >= m.degradedThreshold {
		return model.SourceStatusDegraded
	}
	return model.SourceStatusOnline
}

func (m *HealthMonitor) GetStatus(ctx context.Context, sourceID int64) (*model.DataSourceHealth, error) {
	var health model.DataSourceHealth
	if err := m.db.WithContext(ctx).Where("source_id = ?", sourceID).First(&health).Error; err != nil {
		return nil, err
	}
	return &health, nil
}

func (m *HealthMonitor) ListAll(ctx context.Context) ([]model.DataSourceHealth, error) {
	var healths []model.DataSourceHealth
	if err := m.db.WithContext(ctx).Find(&healths).Error; err != nil {
		return nil, err
	}
	return healths, nil
}
