package model

import "time"

type Agent struct {
	AgentID         string    `gorm:"primaryKey;size:64" json:"agent_id"`
	Hostname        string    `gorm:"column:hostname;size:128;not null" json:"hostname"`
	MachineID       string    `gorm:"column:machine_id;size:128;not null" json:"machine_id"`
	MAC             string    `gorm:"column:mac;size:32;not null" json:"mac"`
	IPv4            string    `gorm:"column:ipv4;size:45;not null" json:"ipv4"`
	LastHeartbeatAt time.Time `gorm:"column:last_heartbeat_at;not null" json:"last_heartbeat_at"`
	BoundLineID     *int64    `gorm:"column:bound_line_id" json:"bound_line_id"`
	Status          string    `gorm:"column:status;size:32;not null;default:PENDING_BIND" json:"status"`
	CreatedAt       time.Time `gorm:"column:created_at;not null;autoCreateTime" json:"created_at"`
	UpdatedAt       time.Time `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (Agent) TableName() string { return "TBL_AGENT" }

const (
	AgentStatusPendingBind = "PENDING_BIND"
	AgentStatusBound       = "BOUND"
	AgentStatusOffline     = "OFFLINE"
)
