package model

import "time"

type CollectCursor struct {
	ID            int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	LineID        int64     `gorm:"column:line_id;not null;uniqueIndex:UQ_CURSOR_LINE" json:"line_id"`
	SourceID      string    `gorm:"column:source_id;size:128;not null" json:"source_id"`
	LastCreatedAt time.Time `gorm:"column:last_created_at;not null" json:"last_created_at"`
	LastSourceID  string    `gorm:"column:last_source_id;size:128;not null" json:"last_source_id"`
	UpdatedAt     time.Time `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (CollectCursor) TableName() string { return "TBL_COLLECT_CURSOR" }
