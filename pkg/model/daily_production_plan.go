package model

import "time"

type DailyProductionPlan struct {
	ID                    int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	PlanDate              string    `gorm:"column:plan_date;type:date;not null;uniqueIndex:UQ_PLAN_DATE_ROW_LINE" json:"plan_date"`
	RowNo                 int       `gorm:"column:row_no;not null;uniqueIndex:UQ_PLAN_DATE_ROW_LINE" json:"row_no"`
	Value                 *int      `gorm:"column:value" json:"value,omitempty"`
	CartonCount           *int      `gorm:"column:carton_count" json:"carton_count,omitempty"`
	UnitsPerCartonSnapshot *int     `gorm:"column:units_per_carton_snapshot" json:"units_per_carton_snapshot,omitempty"`
	LooseQuantity         *int      `gorm:"column:loose_quantity" json:"loose_quantity,omitempty"`
	ActualQuantity        *int      `gorm:"column:actual_quantity" json:"actual_quantity,omitempty"`
	LineCode              string    `gorm:"column:line_code;size:64;not null;default:HW102;uniqueIndex:UQ_PLAN_DATE_ROW_LINE" json:"line_code"`
	InputBy               string    `gorm:"column:input_by;size:128;not null" json:"input_by"`
	InputAt               time.Time `gorm:"column:input_at;not null;autoCreateTime" json:"input_at"`
	UpdatedAt             time.Time `gorm:"column:updated_at;not null;autoUpdateTime" json:"updated_at"`
}

func (DailyProductionPlan) TableName() string { return "TBL_DAILY_PRODUCTION_PLAN" }

const (
	RowTargetOldLine    = 1
	RowActualOldDay     = 2
	RowActualOldNight   = 3
	RowTargetNewLine    = 4
	RowActualNewLine    = 5
	RowTotalActual      = 6
	RowFinishedInbound  = 7
	RowShipment         = 8
	RowInventory        = 9
	RowLineRemaining    = 10
)

var AutoCalcRows = map[int]bool{
	RowTotalActual: true,
	RowInventory:   true,
}

var CartonModeRows = map[int]bool{
	RowActualOldDay:   true,
	RowActualOldNight: true,
	RowActualNewLine:  true,
}

var ValueModeRows = map[int]bool{
	RowTargetOldLine:   true,
	RowTargetNewLine:   true,
	RowFinishedInbound: true,
	RowShipment:        true,
	RowLineRemaining:   true,
}