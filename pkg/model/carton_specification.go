package model

import "time"

type CartonSpecification struct {
	ID              int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	LineCode        string    `gorm:"column:line_code;size:64;not null;uniqueIndex:UQ_CARTON_SPEC_LINE_PROD_TIME" json:"line_code"`
	ProductCode     string    `gorm:"column:product_code;size:64;not null;uniqueIndex:UQ_CARTON_SPEC_LINE_PROD_TIME" json:"product_code"`
	UnitsPerCarton  int       `gorm:"column:units_per_carton;not null" json:"units_per_carton"`
	EffectiveFrom   string    `gorm:"column:effective_from;type:date;not null;uniqueIndex:UQ_CARTON_SPEC_LINE_PROD_TIME" json:"effective_from"`
	EffectiveTo     *string   `gorm:"column:effective_to;type:date" json:"effective_to,omitempty"`
	ConfigBy        string    `gorm:"column:config_by;size:128;not null" json:"config_by"`
	ConfigAt        time.Time `gorm:"column:config_at;not null;autoCreateTime" json:"config_at"`
	UpdatedAt       time.Time `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (CartonSpecification) TableName() string { return "TBL_CARTON_SPECIFICATION" }