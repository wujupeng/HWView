package model

import "time"

type DataSourceHealth struct {
	SourceID            int64      `gorm:"primaryKey" json:"source_id"`
	Status              string     `gorm:"column:status;size:32;not null;default:OFFLINE" json:"status"`
	LastSuccessAt       *time.Time `gorm:"column:last_success_at" json:"last_success_at"`
	LastFailureAt       *time.Time `gorm:"column:last_failure_at" json:"last_failure_at"`
	ConsecutiveFailures int        `gorm:"column:consecutive_failures;not null;default:0" json:"consecutive_failures"`
	LastError           string     `gorm:"column:last_error;type:text" json:"last_error"`
	UpdatedAt           time.Time  `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (DataSourceHealth) TableName() string { return "TBL_DATA_SOURCE_HEALTH" }
