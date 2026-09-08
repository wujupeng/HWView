package model

import "time"

type AuditLog struct {
	ID         int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	Actor      string    `gorm:"column:actor;size:128;not null" json:"actor"`
	Action     string    `gorm:"column:action;size:64;not null" json:"action"`
	TargetType string    `gorm:"column:target_type;size:64;not null" json:"target_type"`
	TargetID   string    `gorm:"column:target_id;size:128" json:"target_id"`
	Change     string    `gorm:"column:change;type:text" json:"change"`
	SudoUsed   bool      `gorm:"column:sudo_used;not null;default:false" json:"sudo_used"`
	CreatedAt  time.Time `gorm:"column:created_at;not null;autoCreateTime" json:"created_at"`
}

func (AuditLog) TableName() string { return "TBL_AUDIT_LOG" }
