package model

import "time"

type ProductionRecord struct {
	ID             int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	LineID         int64     `gorm:"column:line_id;not null;uniqueIndex:UQ_RECORD_LINE_SOURCE" json:"line_id"`
	SourceID       string    `gorm:"column:source_id;size:128;not null;uniqueIndex:UQ_RECORD_LINE_SOURCE" json:"source_id"`
	ProductCode    string    `gorm:"column:product_code;size:64;not null" json:"product_code"`
	Barcode        string    `gorm:"column:barcode;size:128;not null" json:"barcode"`
	BatchNo        string    `gorm:"column:batch_no;size:64;not null" json:"batch_no"`
	Quantity       int       `gorm:"column:quantity;not null" json:"quantity"`
	CreatedAt      time.Time `gorm:"column:created_at;not null" json:"created_at"`
	ProductionDate string    `gorm:"column:production_date;type:date;not null" json:"production_date"`
	CollectedAt    time.Time `gorm:"column:collected_at;not null;autoCreateTime" json:"collected_at"`
}

func (ProductionRecord) TableName() string { return "TBL_PRODUCTION_RECORD" }
