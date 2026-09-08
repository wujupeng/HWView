package model

import "time"

type ProductionLine struct {
	ID          int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	LineCode    string    `gorm:"column:line_code;size:64;uniqueIndex" json:"line_code"`
	LineName    string    `gorm:"column:line_name;size:128;not null" json:"line_name"`
	Customer    string    `gorm:"column:customer;size:64;not null" json:"customer"`
	Product     string    `gorm:"column:product;size:64;not null" json:"product"`
	AdapterType string    `gorm:"column:adapter_type;size:64;not null" json:"adapter_type"`
	Enabled     bool      `gorm:"column:enabled;not null;default:true" json:"enabled"`
	Status      string    `gorm:"column:status;size:32;not null;default:UNCONFIGURED" json:"status"`
	CreatedAt   time.Time `gorm:"column:created_at;not null;autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (ProductionLine) TableName() string { return "TBL_PRODUCTION_LINE" }

const (
	LineStatusUnconfigured = "UNCONFIGURED"
	LineStatusConfigured   = "CONFIGURED"
	LineStatusCollecting   = "COLLECTING"
	LineStatusError        = "ERROR"
)
