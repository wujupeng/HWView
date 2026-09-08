package model

import "time"

type DataSource struct {
	ID              int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	LineID          int64      `gorm:"column:line_id;not null;uniqueIndex:UQ_DATA_SOURCE_LINE_BASEPATH" json:"line_id"`
	AgentID         string     `gorm:"column:agent_id;size:64" json:"agent_id"`
	Hostname        string     `gorm:"column:hostname;size:128" json:"hostname"`
	CurrentIP       string     `gorm:"column:current_ip;size:45;not null" json:"current_ip"`
	Port            int        `gorm:"column:port;not null" json:"port"`
	BasePath        string     `gorm:"column:base_path;size:256;not null;uniqueIndex:UQ_DATA_SOURCE_LINE_BASEPATH" json:"base_path"`
	Enabled         bool       `gorm:"column:enabled;not null;default:true" json:"enabled"`
	Status          string     `gorm:"column:status;size:32;not null;default:OFFLINE" json:"status"`
	LastSuccessAt   *time.Time `gorm:"column:last_success_at" json:"last_success_at"`
	LastErrorAt     *time.Time `gorm:"column:last_error_at" json:"last_error_at"`
	LastHeartbeatAt *time.Time `gorm:"column:last_heartbeat_at" json:"last_heartbeat_at"`
	CreatedAt       time.Time  `gorm:"column:created_at;not null;autoCreateTime" json:"created_at"`
	UpdatedAt       time.Time  `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (DataSource) TableName() string { return "TBL_DATA_SOURCE" }

const (
	SourceStatusOnline    = "ONLINE"
	SourceStatusDegraded  = "DEGRADED"
	SourceStatusOffline   = "OFFLINE"
	SourceStatusSwitching = "SWITCHING"
)
